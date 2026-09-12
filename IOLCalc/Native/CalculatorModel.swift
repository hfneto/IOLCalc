import Foundation
import Observation
import IOLCore

enum Eye: String, CaseIterable, Identifiable {
    case od = "OD"
    case oe = "OE"

    var id: String { rawValue }
    var title: String { self == .od ? "Olho direito" : "Olho esquerdo" }
}

/// Campos de um olho como digitados (texto), para aceitar vírgula ou ponto e campos vazios.
struct EyeForm: Equatable {
    var al = "", k1 = "", k2 = "", kAxis = "", acd = "", lt = "", wtw = "", cct = ""
    var tk1 = "", tk2 = "", tkAxis = ""
    var showTK = false
    var lensID = ""
    var aConstant = ""
    var target = "0,00"
    var enabled = true
    /// Régua da seção 5 (D). Acompanha o alvo até o usuário arrastar.
    var residualSlider = 0.0
    /// Astigmatismo residual (D) digitado; enquanto não tocado, vem do ΔK.
    var cylinder = ""
    var cylinderTouched = false
    var cylinderAxis = "90"

    static let sliderRange = -4.0...1.0

    var lens: IOLLens? { LensCatalog.lens(id: lensID) }
    var km: Double? { Keratometry.mean(k1: Num.parse(k1), k2: Num.parse(k2)) }
    var deltaK: Double? { Keratometry.delta(k1: Num.parse(k1), k2: Num.parse(k2)) }
    var hasTK: Bool { Num.parse(tk1) != nil && Num.parse(tk2) != nil }
    var targetValue: Double { Num.parse(target) ?? 0 }
    /// Texto do campo de astigmatismo residual (pré-preenchido com ΔK até ser editado).
    var cylinderText: String { cylinderTouched ? cylinder : (deltaK.map { Num.fmt($0) } ?? "") }
    var cylinderValue: Double { max(0, Num.parse(cylinderText) ?? 0) }

    /// Biometria no formato do motor; `nil` sem AL ou K.
    var biometry: EyeBiometry? {
        guard let al = Num.parse(al), let km else { return nil }
        return EyeBiometry(axialLength: al, keratometry: km, acd: Num.parse(acd), lensThickness: Num.parse(lt),
                           centralCornealThickness: Num.parse(cct))
    }

    mutating func clearBiometry() {
        al = ""; k1 = ""; k2 = ""; kAxis = ""; acd = ""; lt = ""; wtw = ""; cct = ""
        tk1 = ""; tk2 = ""; tkAxis = ""
    }
}

/// Estado do cálculo de um olho na seção 3.
enum EyeResult {
    case disabled
    case incomplete
    case plan(PowerPlan)
}

@Observable
final class CalculatorModel {
    var patientName = ""
    var od = EyeForm()
    var oe = EyeForm()

    var method: BiometryMethod { didSet { save() } }
    /// ΔA por método, como texto (editável em "avançado").
    var deltaA: [BiometryMethod: String] { didSet { save() } }

    // Seção 5
    var astigmatismOn = false
    var showMonocular = false
    // Seção 6
    var simulationNight = false
    /// Variação individual dos halos: 0 melhor caso, 1 mais comum, 2 pior caso.
    var simulationHaloMode = 1
    // Seção 7
    var odToric = ToricForm(siaAxis: "180")
    var oeToric = ToricForm(siaAxis: "0")
    // Comparador
    var compareEye: Eye = .od
    var compareA = ""
    var compareB = ""

    private static let methodKey = "iol_method"
    private static func deltaKey(_ m: BiometryMethod) -> String { "iol_dA2_\(m.rawValue)" }

    init(defaults: UserDefaults = .standard) {
        method = defaults.string(forKey: Self.methodKey).flatMap(BiometryMethod.init(rawValue:)) ?? .optical
        var d: [BiometryMethod: String] = [:]
        for m in BiometryMethod.allCases {
            d[m] = defaults.string(forKey: Self.deltaKey(m)) ?? Num.fmt(m.defaultDeltaA)
        }
        deltaA = d
        if defaults.bool(forKey: "iol_sample") { fillSample() }
        // Depuração: `-iol_ai_fake_file <arquivo>` aplica o texto do arquivo como se fosse a resposta
        // da IA (por arquivo porque um argumento começando com "{" é lido como plist pelo UserDefaults).
        if let path = defaults.string(forKey: "iol_ai_fake_file"), let fake = try? String(contentsOfFile: path, encoding: .utf8),
           let report = try? BiometryReport.parse(fake) { apply(report) }
    }

    /// Caso de exemplo da prancha de design (argumento de execução `-iol_sample YES`).
    func fillSample() {
        patientName = "Maria da Silva"
        od = EyeForm(al: "23,62", k1: "43,25", k2: "44,10", kAxis: "92", acd: "3,21", lt: "4,52", wtw: "11,8", cct: "541")
        oe = EyeForm(al: "23,70", k1: "43,40", k2: "44,05", kAxis: "88", acd: "3,18", lt: "4,49", wtw: "11,9", cct: "538")
        selectLens("panoptix", for: .od)
        selectLens("panoptix", for: .oe)
        showMonocular = true
        compareA = "vivity"
        compareB = "panoptix"
        suggestToric(.od)
        suggestToric(.oe)
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(method.rawValue, forKey: Self.methodKey)
        for m in BiometryMethod.allCases { defaults.set(deltaA[m] ?? "", forKey: Self.deltaKey(m)) }
    }

    /// ΔA em vigor (método selecionado); texto inválido conta como 0, como na web.
    var currentDeltaA: Double { Num.parse(deltaA[method] ?? "") ?? 0 }

    subscript(eye: Eye) -> EyeForm {
        get { eye == .od ? od : oe }
        set { if eye == .od { od = newValue } else { oe = newValue } }
    }

    func selectLens(_ id: String, for eye: Eye) {
        self[eye].lensID = id
        self[eye].aConstant = LensCatalog.lens(id: id).map { Num.fmt($0.aConstant) } ?? ""
    }

    /// Alvo da seção 2; move a régua da seção 5 junto (limitada à faixa da régua).
    func setTarget(_ text: String, for eye: Eye) {
        self[eye].target = text
        let t = Num.parse(text) ?? 0
        self[eye].residualSlider = min(EyeForm.sliderRange.upperBound, max(EyeForm.sliderRange.lowerBound, t))
    }

    /// Copia LIO, constante A (mesmo personalizada) e alvo do OD para o OE.
    func copyODtoOE() {
        oe.lensID = od.lensID
        oe.aConstant = od.aConstant
        setTarget(od.target, for: .oe)
    }

    // MARK: - Seção 5: defocus e binocular

    /// Olho entra no gráfico quando está ativo e tem LIO escolhida.
    func eyeActive(_ eye: Eye) -> Bool { self[eye].enabled && self[eye].lens != nil }

    func effectiveCylinder(_ eye: Eye) -> Double? { astigmatismOn ? self[eye].cylinderValue : nil }

    /// Residual previsto na seção 3 (nil sem biometria/A).
    func predictedResidual(_ eye: Eye) -> Double? {
        if case .plan(let p) = result(for: eye) { return p.chosen.residual }
        return nil
    }

    /// Refração usada no gráfico: previsto + desvio da régua em relação ao alvo.
    func effectiveResidual(_ eye: Eye) -> Double {
        DefocusModel.effectiveResidual(predicted: predictedResidual(eye), target: self[eye].targetValue, slider: self[eye].residualSlider)
    }

    func monocularVA(_ eye: Eye, at d: Double) -> Double? {
        guard eyeActive(eye), let lens = self[eye].lens else { return nil }
        return DefocusModel.monocularVA(curve: lens.defocusValues, residual: effectiveResidual(eye), defocus: d, cylinder: effectiveCylinder(eye))
    }

    func binocularVA(at d: Double) -> Double? {
        DefocusModel.binocularVA(monocularVA(.od, at: d), monocularVA(.oe, at: d))
    }

    func stereopsis() -> String? {
        guard eyeActive(.od), eyeActive(.oe), let a = od.lens, let b = oe.lens else { return nil }
        return Stereopsis.format(Stereopsis.compute(a.category, b.category, seA: effectiveResidual(.od), seB: effectiveResidual(.oe)))
    }

    // MARK: - Comparador (duas lentes no mesmo olho)

    struct CompareResult {
        let lens: IOLLens
        /// Poder sugerido e residual com a constante A da própria lente; nil sem biometria.
        let power: Double?
        let residual: Double
        let cylinder: Double?
    }

    func compare(_ lensID: String) -> CompareResult? {
        guard let lens = LensCatalog.lens(id: lensID) else { return nil }
        let form = self[compareEye]
        let cyl = effectiveCylinder(compareEye)
        guard let bio = form.biometry else {
            return CompareResult(lens: lens, power: nil, residual: form.targetValue, cylinder: cyl)
        }
        let plan = PowerPlanner.plan(eye: bio, aConstant: lens.aConstant, method: method, deltaA: currentDeltaA, target: form.targetValue)
        return CompareResult(lens: lens, power: plan.chosen.power, residual: plan.chosen.residual, cylinder: cyl)
    }

    func applyCompare(_ lensID: String) {
        selectLens(lensID, for: compareEye)
    }

    func clearBiometry() {
        patientName = ""
        od.clearBiometry()
        oe.clearBiometry()
    }

    /// Preenche a biometria com o que a IA leu (como `fillFromJSON` da web): só os campos
    /// presentes são sobrescritos; o cilindro residual volta a seguir o ΔK.
    func apply(_ report: BiometryReport) {
        if let n = report.name { patientName = n }
        for eye in Eye.allCases {
            let e = report[eye]
            var form = self[eye]
            func set(_ key: String, _ path: WritableKeyPath<EyeForm, String>, digits: Int = 2) {
                if let v = e[key] { form[keyPath: path] = Num.fmt(v, digits) }
            }
            set("AL", \.al); set("K1", \.k1); set("K2", \.k2); set("ACD", \.acd); set("LT", \.lt); set("WTW", \.wtw)
            set("CCT", \.cct, digits: 0); set("K2_axis", \.kAxis, digits: 0)
            set("TK1", \.tk1); set("TK2", \.tk2); set("TK2_axis", \.tkAxis, digits: 0)
            form.cylinderTouched = false
            self[eye] = form
        }
    }

    func result(for eye: Eye) -> EyeResult {
        let form = self[eye]
        guard form.enabled else { return .disabled }
        guard let bio = form.biometry, let a = Num.parse(form.aConstant) else { return .incomplete }
        let plan = PowerPlanner.plan(eye: bio, k1: Num.parse(form.k1), k2: Num.parse(form.k2),
                                     aConstant: a, method: method, deltaA: currentDeltaA,
                                     target: Num.parse(form.target) ?? 0)
        return .plan(plan)
    }
}

/// Planejamento tórico de um olho, como digitado. Os campos "override" ficam `nil` enquanto o
/// usuário não os edita: até lá seguem a biometria da seção 1 (como os `dataset.touched` da web).
struct ToricForm: Equatable {
    var modelOverride: CornealAstigmatismModel?
    var k1Override: String?
    var k2Override: String?
    var kAxisOverride: String?
    var totalCylinderOverride: String?
    var totalAxisOverride: String?
    var sia = "0,10"
    var siaAxis: String
    var iolCylinder = "0,00"
    var iolAxis = "90"
    /// Plataforma escolhida à mão; vale enquanto a LIO da seção 2 for a mesma (depois segue o fabricante).
    var platformOverride: PlatformChoice?
    /// Razão digitada; vale enquanto a plataforma em vigor for a mesma.
    var ratioOverride: RatioChoice?

    struct PlatformChoice: Equatable { var lensID: String; var id: String }
    struct RatioChoice: Equatable { var platformID: String; var text: String }

    init(siaAxis: String) { self.siaAxis = siaAxis }
}

/// Razão de toricidade em vigor e a sua origem.
struct ToricRatio {
    enum Source: String { case manual = "(manual)", eye = "(ELP do olho)", platform = "(padrão plataforma)" }
    let value: Double
    let source: Source
}

extension CalculatorModel {
    subscript(toric eye: Eye) -> ToricForm {
        get { eye == .od ? odToric : oeToric }
        set { if eye == .od { odToric = newValue } else { oeToric = newValue } }
    }

    // MARK: Campos efetivos (override ou biometria)

    /// Com TK medido a base passa a "Total" automaticamente (`pullTorK` da web).
    func toricModel(_ eye: Eye) -> CornealAstigmatismModel {
        self[toric: eye].modelOverride ?? (self[eye].hasTK ? .total : .abulafiaKoch)
    }

    func toricK1Text(_ eye: Eye) -> String { self[toric: eye].k1Override ?? self[eye].k1 }
    func toricK2Text(_ eye: Eye) -> String { self[toric: eye].k2Override ?? self[eye].k2 }
    func toricKAxisText(_ eye: Eye) -> String { self[toric: eye].kAxisOverride ?? (self[eye].kAxis.isEmpty ? "90" : self[eye].kAxis) }
    func toricTotalCylinderText(_ eye: Eye) -> String {
        if let o = self[toric: eye].totalCylinderOverride { return o }
        let f = self[eye]
        if let a = Num.parse(f.tk1), let b = Num.parse(f.tk2) { return Num.fmt(abs(b - a)) }
        return ""
    }
    func toricTotalAxisText(_ eye: Eye) -> String { self[toric: eye].totalAxisOverride ?? (self[eye].tkAxis.isEmpty ? "90" : self[eye].tkAxis) }

    /// Origem dos K mostrada no cabeçalho do cartão.
    func toricSourceLabel(_ eye: Eye) -> String {
        let f = self[eye]
        if let a = Num.parse(f.tk1), let b = Num.parse(f.tk2) { return "TK da biometria (ΔTK \(Num.fmt(abs(b - a))) D)" }
        if let d = f.deltaK { return "da biometria (ΔK \(Num.fmt(d)) D)" }
        return "preencha K1/K2 na Biometria"
    }

    func toricPlatformID(_ eye: Eye) -> String {
        let form = self[eye]
        if let o = self[toric: eye].platformOverride, o.lensID == form.lensID { return o.id }
        return form.lens.map { ToricPlatform.id(forManufacturer: $0.manufacturer) } ?? ToricPlatform.all[0].id
    }

    func toricPlatform(_ eye: Eye) -> ToricPlatform { ToricPlatform.platform(id: toricPlatformID(eye)) }

    func setToricPlatform(_ id: String, for eye: Eye) {
        self[toric: eye].platformOverride = .init(lensID: self[eye].lensID, id: id)
    }

    /// Razão: manual > calculada pela ELP do olho (SRK/T com o poder sugerido) > padrão da plataforma.
    func toricRatio(_ eye: Eye) -> ToricRatio {
        let platform = toricPlatform(eye)
        if let o = self[toric: eye].ratioOverride, o.platformID == platform.id {
            return ToricRatio(value: Num.parse(o.text) ?? ToricInput().ratio, source: .manual)
        }
        if case .plan(let plan) = result(for: eye),
           let r = ToricPlanner.toricityRatio(eye: plan.eye, effectiveA: plan.effectiveA, implantedPower: plan.chosen.power,
                                              iolCylinder: Num.parse(self[toric: eye].iolCylinder) ?? 0) {
            return ToricRatio(value: r, source: .eye)
        }
        return ToricRatio(value: platform.ratio, source: .platform)
    }

    /// Texto do campo de razão (2 casas, como a web preenche).
    func toricRatioText(_ eye: Eye) -> String {
        if let o = self[toric: eye].ratioOverride, o.platformID == toricPlatformID(eye) { return o.text }
        return Num.fmt(toricRatio(eye).value)
    }

    func setToricRatioText(_ text: String, for eye: Eye) {
        self[toric: eye].ratioOverride = .init(platformID: toricPlatformID(eye), text: text)
    }

    // MARK: Cálculo

    func toricInput(_ eye: Eye) -> ToricInput {
        let t = self[toric: eye]
        var i = ToricInput()
        i.model = toricModel(eye)
        i.k1 = Num.parse(toricK1Text(eye))
        i.k2 = Num.parse(toricK2Text(eye))
        i.kAxis = Num.parse(toricKAxisText(eye)) ?? 90
        i.totalCylinder = Num.parse(toricTotalCylinderText(eye)) ?? 0
        i.totalAxis = Num.parse(toricTotalAxisText(eye)) ?? 90
        i.sia = Num.parse(t.sia) ?? 0
        i.siaAxis = Num.parse(t.siaAxis) ?? 180
        i.iolCylinder = Num.parse(t.iolCylinder) ?? 0
        i.iolAxis = Num.parse(t.iolAxis) ?? 90
        i.ratio = toricRatio(eye).value
        return i
    }

    func toricPlan(_ eye: Eye) -> ToricPlan { ToricPlanner.plan(toricInput(eye)) }

    /// "Sugerir ideal": degrau da plataforma mais próximo e eixo no meridiano curvo total.
    func suggestToric(_ eye: Eye) {
        let s = ToricPlanner.suggestion(for: toricPlan(eye), platform: toricPlatform(eye))
        self[toric: eye].iolCylinder = Num.fmt(s.cylinder)
        self[toric: eye].iolAxis = Num.fmt(s.axis, 0)
    }

    func alignToricToTotal(_ eye: Eye) {
        self[toric: eye].iolAxis = Num.fmt(PowerPlanner.roundHalfUp(toricPlan(eye).totalAxis), 0)
    }

    /// Copia os campos tóricos de um olho para o outro (os que seguem a biometria continuam seguindo).
    func copyToric(from: Eye, to: Eye) {
        var dst = self[toric: to]
        let src = self[toric: from]
        dst.modelOverride = src.modelOverride
        dst.k1Override = src.k1Override; dst.k2Override = src.k2Override; dst.kAxisOverride = src.kAxisOverride
        dst.totalCylinderOverride = src.totalCylinderOverride; dst.totalAxisOverride = src.totalAxisOverride
        dst.sia = src.sia; dst.siaAxis = src.siaAxis
        dst.iolCylinder = src.iolCylinder; dst.iolAxis = src.iolAxis
        let platformID = toricPlatformID(from)
        dst.platformOverride = .init(lensID: self[to].lensID, id: platformID)
        dst.ratioOverride = src.ratioOverride.map { .init(platformID: platformID, text: $0.text) }
        self[toric: to] = dst
    }

    // MARK: - Seção 6: simulação visual

    /// Astigmatismo residual usado nos quadros: o olho "dominante" é o de menor cilindro.
    func simulationAstigmatism() -> (cylinder: Double, axis: Double)? {
        guard astigmatismOn else { return nil }
        var best: (cylinder: Double, axis: Double)?
        for eye in Eye.allCases where eyeActive(eye) {
            let c = self[eye].cylinderValue
            if best == nil || c < best!.cylinder { best = (c, Num.parse(self[eye].cylinderAxis) ?? 90) }
        }
        return best
    }

    /// Grau de disfotopsia da combinação (o maior entre as lentes ativas).
    func simulationDysphotopsia() -> Int {
        Eye.allCases.filter { eyeActive($0) }.compactMap { self[$0].lens?.dysphotopsia }.max() ?? 0
    }

    /// AV (logMAR) usada em um quadro; `nil` sem olho ativo.
    func simulationAcuity(_ tile: VisualSimulation.Tile) -> Double? {
        binocularVA(at: tile.defocus).map { VisualSimulation.acuity($0, night: simulationNight) }
    }
}

/// Números no padrão brasileiro (vírgula), aceitando ponto na digitação.
enum Num {
    static func parse(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !t.isEmpty, let v = Double(t), v.isFinite else { return nil }
        return v
    }

    static func fmt(_ v: Double, _ digits: Int = 2, signed: Bool = false) -> String {
        var s = String(format: "%.\(digits)f", v).replacingOccurrences(of: ".", with: ",")
        if s.hasPrefix("-") { s = "−" + s.dropFirst() } else if signed, v > 0 { s = "+" + s }
        return s
    }

    static func fmt(_ v: Double?, _ digits: Int = 2) -> String {
        v.map { fmt($0, digits) } ?? "—"
    }
}

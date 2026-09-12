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

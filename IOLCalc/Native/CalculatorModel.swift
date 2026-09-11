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

    var lens: IOLLens? { LensCatalog.lens(id: lensID) }
    var km: Double? { Keratometry.mean(k1: Num.parse(k1), k2: Num.parse(k2)) }
    var deltaK: Double? { Keratometry.delta(k1: Num.parse(k1), k2: Num.parse(k2)) }
    var hasTK: Bool { Num.parse(tk1) != nil && Num.parse(tk2) != nil }

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

    /// Copia LIO, constante A (mesmo personalizada) e alvo do OD para o OE.
    func copyODtoOE() {
        oe.lensID = od.lensID
        oe.aConstant = od.aConstant
        oe.target = od.target
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

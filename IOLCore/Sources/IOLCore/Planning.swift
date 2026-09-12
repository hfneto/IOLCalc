import Foundation

/// Como a biometria foi medida. As constantes A do catálogo são de biometria óptica
/// (IOLcon/ULIB); os outros métodos recebem um ΔA (Shammas 2021; conversão de Hill).
public enum BiometryMethod: String, CaseIterable, Sendable, Codable, Identifiable {
    case optical = "optica"
    case immersion = "imersao"
    case contact = "us"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .optical: return "Biometria óptica (IOLMaster, Lenstar, Argos…)"
        case .immersion: return "Ultrassom de imersão"
        case .contact: return "Ultrassom de contato (aplanação)"
        }
    }

    public var shortLabel: String {
        switch self {
        case .optical: return "óptica"
        case .immersion: return "imersão"
        case .contact: return "US contato"
        }
    }

    /// ΔA padrão somado à constante A do catálogo.
    public var defaultDeltaA: Double {
        switch self {
        case .optical: return 0
        case .immersion: return -0.23
        case .contact: return -0.50
        }
    }
}

/// Um poder candidato (passo de 0,5 D) e o residual mediano previsto para ele.
public struct PowerCandidate: Sendable, Hashable {
    public let power: Double
    public let residual: Double
}

/// Alertas de olho atípico — casos em que as fórmulas publicadas mais erram.
public enum EyeWarning: Sendable, Hashable {
    case veryShortEye(al: Double)
    case veryLongEye(al: Double)
    case flatCornea(km: Double)
    case steepCornea(km: Double)
    case highAstigmatism(deltaK: Double)
    case missingACD
    case missingLT
    case formulaSpread(Double)

    public var message: String {
        func f(_ v: Double) -> String { String(format: "%.2f", v) }
        switch self {
        case .veryShortEye(let al): return "AL \(f(al)) mm — olho muito curto (as clássicas erram mais; priorize ESCRS/Barrett)"
        case .veryLongEye(let al): return "AL \(f(al)) mm — olho muito longo (Wang-Koch aplicado ao Holladay 1, mas confira nas modernas)"
        case .flatCornea(let km): return "Km \(f(km)) D — córnea plana (pós-cirurgia refrativa? use calculadora pós-LASIK)"
        case .steepCornea(let km): return "Km \(f(km)) D — córnea muito curva (ceratocone? fórmulas padrão não se aplicam)"
        case .highAstigmatism(let dk): return "ΔK \(f(dk)) D — astigmatismo alto; confirme na Barrett Toric"
        case .missingACD: return "ACD ausente — Haigis e Castrop usando 3,37 mm padrão (preencha para maior precisão)"
        case .missingLT: return "LT ausente — Castrop usando 4,7 mm padrão"
        case .formulaSpread(let s): return "Fórmulas divergem \(f(s)) D entre si — olho atípico, redobre a conferência externa"
        }
    }
}

/// Resultado do planejamento do poder para um olho: linhas por fórmula, candidatos em
/// passos de 0,5 D, sugestão ("primeira lente que não deixa hipermetropia") e alertas.
/// Porte fiel do `recalc()` da versão web.
public struct PowerPlan: Sendable {
    public struct Row: Sendable, Hashable, Identifiable {
        public let formula: FormulaKey
        public let isRecommended: Bool
        /// Poder para emetropia (alvo 0).
        public let emmetropiaPower: Double
        /// Poder para o alvo escolhido.
        public let targetPower: Double
        public var id: FormulaKey { formula }
    }

    public let eye: EyeBiometry
    /// Constante A informada (catálogo ou editada).
    public let aConstant: Double
    /// Ajuste pelo método de biometria.
    public let deltaA: Double
    public let method: BiometryMethod
    public let target: Double
    public let recommended: [FormulaKey]
    public let rows: [Row]
    /// Mediana, nas fórmulas recomendadas, do poder para o alvo.
    public let medianPower: Double
    /// Cinco candidatos: mediana arredondada a 0,5 D, ±1,0 D.
    public let candidates: [PowerCandidate]
    public let chosen: PowerCandidate
    /// Candidato logo abaixo da sugestão (residual levemente hipermetrópico), se houver.
    public let alternative: PowerCandidate?
    /// `false` quando nenhum candidato atinge o alvo (sugestão cai no maior poder).
    public let reachesTarget: Bool
    public let warnings: [EyeWarning]

    public var effectiveA: Double { aConstant + deltaA }

    /// Residual previsto (D) por uma fórmula específica para um poder implantado.
    public func residual(_ formula: FormulaKey, at power: Double) -> Double {
        IOLFormulas.predictedRefraction(formula, eye: eye, aConstant: effectiveA, implantedPower: power)
    }
}

public enum PowerPlanner {
    /// Passo dos candidatos de poder (D).
    public static let step = 0.5

    /// Planeja o poder da LIO. `k1`/`k2` servem só para o alerta de ΔK.
    public static func plan(eye: EyeBiometry, k1: Double? = nil, k2: Double? = nil,
                            aConstant: Double, method: BiometryMethod = .optical, deltaA: Double? = nil,
                            target: Double = 0) -> PowerPlan {
        let dA = deltaA ?? method.defaultDeltaA
        let aEff = aConstant + dA
        let al = eye.axialLength
        let active = IOLFormulas.activeFormulas(axialLength: al)
        let recommended = IOLFormulas.recommendedFormulas(axialLength: al)
        let rows = active.map { f in
            PowerPlan.Row(formula: f, isRecommended: recommended.contains(f),
                          emmetropiaPower: IOLFormulas.power(f, eye: eye, aConstant: aEff, target: 0),
                          targetPower: IOLFormulas.power(f, eye: eye, aConstant: aEff, target: target))
        }
        let recRows = rows.filter(\.isRecommended)
        let medP = median(recRows.map(\.targetPower))
        let base = roundHalfUp(medP / step) * step
        let residAt = { (p: Double) -> Double in
            median(recRows.map { IOLFormulas.predictedRefraction($0.formula, eye: eye, aConstant: aEff, implantedPower: p) })
        }
        let candidates: [PowerCandidate] = [-1.0, -0.5, 0, 0.5, 1.0].map { k in
            let p = ((base + k) * 100).rounded() / 100
            return PowerCandidate(power: p, residual: residAt(p))
        }
        // Regra clínica: a PRIMEIRA lente (menor poder) cujo residual fica no alvo ou miópico a ele.
        let ok = candidates.filter { $0.residual <= target + 1e-6 }
        let chosen = ok.first ?? candidates[candidates.count - 1]
        let alternative = candidates.filter { $0.power < chosen.power }.last

        return PowerPlan(eye: eye, aConstant: aConstant, deltaA: dA, method: method, target: target,
                         recommended: recommended, rows: rows, medianPower: medP, candidates: candidates,
                         chosen: chosen, alternative: alternative, reachesTarget: !ok.isEmpty,
                         warnings: warnings(eye: eye, k1: k1, k2: k2, targetPowers: rows.map(\.targetPower)))
    }

    public static func warnings(eye: EyeBiometry, k1: Double?, k2: Double?, targetPowers: [Double]) -> [EyeWarning] {
        var w: [EyeWarning] = []
        let al = eye.axialLength, km = eye.keratometry
        if al < 21 { w.append(.veryShortEye(al: al)) } else if al > 27 { w.append(.veryLongEye(al: al)) }
        if km < 40 { w.append(.flatCornea(km: km)) }
        if km > 48 { w.append(.steepCornea(km: km)) }
        if let k1, let k2, abs(k2 - k1) > 2.5 { w.append(.highAstigmatism(deltaK: abs(k2 - k1))) }
        if IOLFormulas.usable(eye.acd) == nil { w.append(.missingACD) }
        if IOLFormulas.usable(eye.lensThickness) == nil { w.append(.missingLT) }
        if let hi = targetPowers.max(), let lo = targetPowers.min(), hi - lo > 1.0 { w.append(.formulaSpread(hi - lo)) }
        return w
    }

    /// Mediana (média dos dois centrais quando o número de valores é par).
    public static func median(_ values: [Double]) -> Double {
        let a = values.sorted()
        let n = a.count
        guard n > 0 else { return .nan }
        return n % 2 == 1 ? a[(n - 1) / 2] : (a[n / 2 - 1] + a[n / 2]) / 2
    }

    /// `Math.round` do JavaScript: meio arredonda para +∞ (−1,5 → −1).
    public static func roundHalfUp(_ x: Double) -> Double {
        (x + 0.5).rounded(.down)
    }
}

/// Ceratometria média a partir de K1/K2, como a versão web (`eyeData`).
public enum Keratometry {
    public static func mean(k1: Double?, k2: Double?) -> Double? {
        switch (k1, k2) {
        case let (a?, b?): return (a + b) / 2
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }

    public static func delta(k1: Double?, k2: Double?) -> Double? {
        guard let k1, let k2 else { return nil }
        return abs(k2 - k1)
    }
}

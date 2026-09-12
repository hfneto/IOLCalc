import Foundation

/// Curva de defocus, acuidade mono/binocular e conversões de escala.
///
/// As curvas do catálogo (`IOLLens.defocusValues`) são o resultado BINOCULAR dos estudos
/// dos fabricantes. Portanto a AV monocular = curva + penalidade de somação, e a AV
/// binocular do paciente = combinação das duas monoculares (em olhos simétricos ela
/// reproduz exatamente a curva publicada, nunca melhor).
public enum DefocusModel {
    /// Dioptrias de defocus em que o catálogo é medido.
    public static let defocusAxis: [Double] = [1.0, 0.5, 0.0, -0.5, -1.0, -1.5, -2.0, -2.5, -3.0]
    /// Além deste defocus os valores são extrapolação.
    public static let extrapolationFrom = -3.0
    /// Ganho binocular (~1 linha) em olhos simétricos.
    public static let summationLogMAR = 0.07
    /// Pontos plotados no gráfico: +1,0 a −4,0 D em passos de 0,25 (21 pontos), como a versão web.
    public static let plotAxis: [Double] = stride(from: 1.0, through: -4.0, by: -0.25).map { ($0 * 100).rounded() / 100 }
    /// Defocus das distâncias de leitura usadas nas métricas.
    public static let farDefocus = 0.0
    public static let intermediateDefocus = -1.5   // 66 cm
    public static let nearDefocus = -2.5           // 40 cm
    /// Limites do eixo Y do gráfico (logMAR, invertido: menor é melhor).
    public static let plotLogMARRange = -0.2...0.8

    /// Refração efetiva usada no gráfico: residual previsto (ou o alvo, sem biometria) mais o
    /// desvio da régua em relação ao alvo. Régua no alvo ⇒ refração prevista.
    public static func effectiveResidual(predicted: Double?, target: Double, slider: Double) -> Double {
        (predicted ?? target) + (slider - target)
    }

    /// AV binocular no defocus `d` a partir das monoculares disponíveis (uma só ⇒ ela mesma).
    public static func binocularVA(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (a?, b?): return binocularCombine(a, b)
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }

    /// Amostra a curva em qualquer defocus `t` (interpolação linear; extrapolação linear limitada).
    public static func sampleCurve(_ values: [Double], at t: Double) -> Double {
        let x = defocusAxis
        let n = x.count - 1
        var v = 0.0
        if t >= x[0] {
            v = values[0] + (values[0] - values[1]) * (t - x[0]) / (x[0] - x[1])
        } else if t <= x[n] {
            v = values[n] + (values[n] - values[n - 1]) * (t - x[n]) / (x[n] - x[n - 1])
        } else {
            for j in 0..<n where t <= x[j] && t >= x[j + 1] {
                let f = (t - x[j]) / (x[j + 1] - x[j])
                v = values[j] + f * (values[j + 1] - values[j])
                break
            }
        }
        return max(-0.15, min(0.85, v))
    }

    /// Penalidade (logMAR) de cilindro residual não corrigido.
    public static func astigmatismPenalty(cylinder: Double?) -> Double {
        guard let cyl = cylinder, cyl > 0 else { return 0 }
        return min(0.60, 0.16 * cyl)
    }

    /// AV monocular (logMAR) no defocus `d` (0 = longe) com residual esférico e cilindro aplicados.
    public static func monocularVA(curve: [Double], residual: Double, defocus d: Double, cylinder: Double?) -> Double {
        min(0.95, sampleCurve(curve, at: d - residual) + summationLogMAR + astigmatismPenalty(cylinder: cylinder))
    }

    /// Somação binocular: devolve o bônus integral com olhos iguais; decai com anisometropia
    /// e some com diferença > 0,30 logMAR.
    public static func binocularCombine(_ a: Double, _ b: Double) -> Double {
        let diff = abs(a - b)
        let bonus = summationLogMAR * max(0, 1 - diff / 0.30)
        return max(-0.20, min(a, b) - bonus)
    }

    public static func snellen(fromLogMAR l: Double) -> String {
        let d = Int((20 / pow(10, -l)).rounded(.toNearestOrAwayFromZero))
        return "20/\(d)"
    }

    public static func jaeger(fromLogMAR l: Double) -> String {
        let table: [(Double, String)] = [
            (0.04, "J1+"), (0.13, "J1"), (0.21, "J2"), (0.34, "J3"), (0.44, "J5"),
            (0.52, "J7"), (0.62, "J10"), (0.72, "J11"), (0.85, "J16"),
        ]
        for (limit, j) in table where l <= limit { return j }
        return ">J16"
    }
}

/// Estereopsia estimada (segundos de arco) a partir das classes de LIO e da anisometropia.
public enum Stereopsis {
    public static func base(_ a: LensCategory, _ b: LensCategory) -> Int {
        func mono(_ c: LensCategory) -> Bool { c == .monofocal || c == .enhancedMonofocal }
        func edof(_ c: LensCategory) -> Bool { c == .edof }
        func tri(_ c: LensCategory) -> Bool { c == .trifocal || c == .continuous || c == .bifocal }
        if mono(a) && mono(b) { return 40 }
        if edof(a) && edof(b) { return 50 }
        if tri(a) && tri(b) { return 65 }
        if (mono(a) && edof(b)) || (edof(a) && mono(b)) { return 55 }
        if (mono(a) && tri(b)) || (tri(a) && mono(b)) { return 85 }
        return 75
    }

    public static func anisometropia(_ d: Double) -> Int {
        if d < 0.25 { return 40 }
        if d <= 0.50 { return 60 }
        if d <= 0.75 { return 90 }
        if d <= 1.0 { return 140 }
        if d <= 1.5 { return 250 }
        return 400
    }

    /// `seA`/`seB`: equivalente esférico residual de cada olho (D).
    public static func compute(_ a: LensCategory, _ b: LensCategory, seA: Double, seB: Double) -> Int {
        let base = Double(base(a, b))
        let aniso = Double(anisometropia(abs(seA - seB)))
        let main = max(base, aniso), minor = min(base, aniso)
        return Int((main + (minor - 40) * 0.3).rounded(.toNearestOrAwayFromZero))
    }

    public static func format(_ s: Int) -> String {
        s >= 400 ? "≥400″ (limitada)" : "\(s)″"
    }
}

import Foundation

/// Parâmetros da simulação visual (seção 6): quadros ampliados em escala física, com o
/// desfoque derivado da AV binocular prevista. Porte das constantes e funções da versão web.
public enum VisualSimulation {
    /// Pixels de quadro por minuto de arco (quadro 2× → 2 px/′ na tela).
    public static let pixelsPerArcMinute = 4.0
    /// Tamanho do quadro em pixels: 280′ × 180′ (4,7° × 3,0°).
    public static let tileWidth = 1120.0
    public static let tileHeight = 720.0
    /// Perda de contraste das ópticas difrativas por grau de disfotopsia (0–3); maior à noite.
    public static let contrastDay: [Double] = [1, 0.95, 0.86, 0.78]
    public static let contrastNight: [Double] = [1, 0.9, 0.76, 0.66]
    /// Penalidade mesópica (logMAR) somada à noite.
    public static let nightPenalty = 0.08
    /// Teto da AV à noite (logMAR).
    public static let nightCeiling = 0.85
    /// Multiplicador de halos por variação individual: melhor caso, mais comum, pior caso.
    public static let haloModeFactors: [Double] = [0.45, 1.0, 1.9]
    public static let dysphotopsiaLabels = ["baixa", "baixa a moderada", "moderada", "alta"]
    public static let haloModeLabels = ["melhor caso", "quadro mais comum", "pior caso"]

    /// Uma distância da cena fotográfica e o defocus equivalente.
    public struct Distance: Sendable, Hashable, Identifiable {
        public let id: String
        public let label: String
        public let distanceCm: Double
        public let defocus: Double
    }

    /// As três camadas das cenas: celular na mão, tela a 66 cm (notebook de dia, GPS à noite) e a rua.
    public static let distances: [Distance] = [
        Distance(id: "near", label: "Celular · 40 cm", distanceCm: 40, defocus: -2.5),
        Distance(id: "mid", label: "66 cm", distanceCm: 66, defocus: -1.5),
        Distance(id: "far", label: "Rua · longe", distanceCm: 5000, defocus: 0),
    ]

    /// Pixels de cena por minuto de arco usados só para o desfoque das fotos (a cena tem ampliação
    /// menor do que a real; o desfoque mantém a escala de 2 px/′ da versão anterior na tela).
    public static let sceneBlurPixelsPerArcMinute = 2.0
    public static let sceneWidth = 1120.0
    public static let sceneHeight = 720.0

    /// σ do desfoque (px) para uma ampliação qualquer.
    public static func blurSigma(logMAR l: Double, pixelsPerArcMinute k: Double) -> Double {
        min(40, max(0, 0.6 * (pow(10, max(0, l)) - 1) * k))
    }

    /// σ do desfoque gaussiano (px de quadro) a partir da AV: MAR = 10^logMAR; nítido em 20/20.
    public static func blurSigma(logMAR l: Double) -> Double {
        min(40, max(0, 0.6 * (pow(10, max(0, l)) - 1) * pixelsPerArcMinute))
    }

    /// Tamanho em px de quadro de um objeto de `mm` a `cm` de distância.
    public static func pixels(forMillimetres mm: Double, at cm: Double) -> Double {
        (mm / (cm * 10)) * 3437.75 * pixelsPerArcMinute
    }

    /// AV usada no quadro: à noite soma a penalidade mesópica, limitada ao teto.
    public static func acuity(_ binocularLogMAR: Double, night: Bool) -> Double {
        night ? min(nightCeiling, binocularLogMAR + nightPenalty) : binocularLogMAR
    }

    /// Arrasto (px de quadro) do borrão direcional do astigmatismo: 1 D ≈ 10′ de arco.
    public static func directionalBlur(cylinder: Double) -> Double {
        min(120, cylinder * 5 * pixelsPerArcMinute)
    }

    /// Intensidade dos halos pela classe da lente (0–3) e pelo modo de variação individual.
    public static func haloIntensity(dysphotopsia dys: Int, mode: Int) -> Double {
        Double(dys) / 3 * haloModeFactors[max(0, min(2, mode))]
    }

    public static func contrast(dysphotopsia dys: Int, night: Bool) -> Double {
        (night ? contrastNight : contrastDay)[max(0, min(3, dys))]
    }
}

import Foundation

/// Astigmatismo como vetor de duplo-ângulo (x = M·cos 2θ, y = M·sin 2θ), com θ = meridiano
/// curvo em graus (0–180). Nesta convenção x positivo é contra-a-regra (ATR).
/// Porte fiel do módulo tórico da versão web (`aVec`, `vAstig`, `vAdd`, `vSub`).
public struct AstigmatismVector: Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// Vetor a partir de magnitude (D) e meridiano curvo (°).
    public init(magnitude: Double, axis: Double) {
        let a = 2 * axis * .pi / 180
        x = magnitude * cos(a)
        y = magnitude * sin(a)
    }

    public static let zero = AstigmatismVector(x: 0, y: 0)

    public var magnitude: Double { (x * x + y * y).squareRoot() }

    /// Meridiano curvo (°), normalizado a [0, 180) como `((ax % 180) + 180) % 180` do JS.
    public var axis: Double {
        let ax = 0.5 * atan2(y, x) * 180 / .pi
        return (ax.truncatingRemainder(dividingBy: 180) + 180).truncatingRemainder(dividingBy: 180)
    }

    public static func + (a: AstigmatismVector, b: AstigmatismVector) -> AstigmatismVector { .init(x: a.x + b.x, y: a.y + b.y) }
    public static func - (a: AstigmatismVector, b: AstigmatismVector) -> AstigmatismVector { .init(x: a.x - b.x, y: a.y - b.y) }
}

/// Base usada para estimar o astigmatismo corneano total.
public enum CornealAstigmatismModel: String, CaseIterable, Sendable, Codable, Identifiable {
    case anterior = "ant"
    case abulafiaKoch = "ak"
    case naeserSavini = "post"
    case total = "total"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .anterior: return "Córnea anterior (K medido)"
        case .abulafiaKoch: return "Anterior + posterior (Abulafia-Koch)"
        case .naeserSavini: return "Anterior + posterior (Næser-Savini)"
        case .total: return "Total (TK / K posterior medido)"
        }
    }

    public var shortLabel: String {
        switch self {
        case .anterior: return "K anterior"
        case .abulafiaKoch: return "Abulafia-Koch"
        case .naeserSavini: return "Næser-Savini"
        case .total: return "TK total"
        }
    }

    /// Explicação mostrada abaixo do seletor (texto da versão web).
    public var note: String? {
        switch self {
        case .abulafiaKoch:
            return "Astig. total estimado pela regressão Abulafia-Koch (JCRS 2016;42:663-671), aplicada aos componentes de duplo-ângulo do K anterior: x′ = 0,508 + 0,926·x · y′ = 0,009 + 0,932·y. Foi a regressão com melhor resultado nos estudos comparativos (equivalente ao Barrett Toric). Para máxima precisão use o modo Total (TK/K posterior medido)."
        case .naeserSavini:
            return "Astig. total estimado do K anterior pela regressão Næser-Savini (corrige a córnea posterior conforme a orientação): 0,103 + 0,836·K + 0,457·cos(2·eixo). Para máxima precisão use o modo Total (TK/K posterior medido)."
        default:
            return nil
        }
    }
}

/// Regressões que estimam o astigmatismo corneano total a partir do K anterior.
public enum ToricRegression {
    /// Abulafia-Koch (Abulafia, Koch, Wang et al., JCRS 2016;42:663-671): regressão linear dos
    /// componentes de duplo-ângulo. O intercepto +0,508 em x é a córnea posterior (ATR).
    public static func abulafiaKoch(_ v: AstigmatismVector) -> AstigmatismVector {
        AstigmatismVector(x: 0.508 + 0.926 * v.x, y: 0.009 + 0.932 * v.y)
    }

    /// Næser-Savini: magnitude total a partir do cilindro anterior e da orientação do meridiano curvo.
    public static func naeserSavini(cylinder: Double, axis: Double) -> Double {
        max(0, 0.103 + 0.836 * cylinder + 0.457 * cos(2 * axis * .pi / 180))
    }
}

/// Plataforma tórica: razão de toricidade padrão e degraus de cilindro disponíveis (plano da LIO).
public struct ToricPlatform: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let ratio: Double
    public let steps: [Double]

    public static let all: [ToricPlatform] = [
        ToricPlatform(id: "alcon", name: "Alcon Clareon/AcrySof (T2–T9)", ratio: 1.46, steps: [1.00, 1.50, 2.25, 3.00, 3.75, 4.50, 5.25, 6.00]),
        ToricPlatform(id: "hoya", name: "HOYA Vivinex Toric (T2–T9)", ratio: 1.45, steps: [1.00, 1.50, 2.25, 3.00, 3.75, 4.50, 5.25, 6.00]),
        ToricPlatform(id: "jj", name: "J&J Tecnis Toric", ratio: 1.46, steps: [1.00, 1.50, 2.00, 2.75, 3.25, 4.00]),
        ToricPlatform(id: "zeiss", name: "Zeiss AT TORBI (0,5)", ratio: 1.37, steps: (0..<23).map { 1.0 + Double($0) * 0.5 }),
        ToricPlatform(id: "rayner", name: "Rayner (0,5)", ratio: 1.46, steps: (0..<21).map { 1.0 + Double($0) * 0.5 }),
        ToricPlatform(id: "generic", name: "Genérico (0,25)", ratio: 1.46, steps: (0..<24).map { 0.75 + Double($0) * 0.25 }),
    ]

    public static let byID: [String: ToricPlatform] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func platform(id: String) -> ToricPlatform { byID[id] ?? all[0] }

    /// Plataforma correspondente ao fabricante da LIO escolhida na seção 2 (`lensPlatformId` da web).
    public static func id(forManufacturer manufacturer: String) -> String {
        let m = manufacturer.lowercased()
        if m.contains("alcon") { return "alcon" }
        if m.contains("hoya") { return "hoya" }
        if m.contains("j&j") { return "jj" }
        if m.contains("zeiss") { return "zeiss" }
        if m.contains("rayner") { return "rayner" }
        return "generic"
    }
}

/// Entradas do planejamento tórico de um olho, já numéricas (valores ausentes = padrões da web).
public struct ToricInput: Sendable, Hashable {
    public var model: CornealAstigmatismModel = .abulafiaKoch
    /// K plano / K curvo (D); sem os dois, o cilindro anterior é 0.
    public var k1: Double?
    public var k2: Double?
    /// Eixo do K curvo (°).
    public var kAxis: Double = 90
    /// Modo Total: astigmatismo total medido e o seu eixo curvo.
    public var totalCylinder: Double = 0
    public var totalAxis: Double = 90
    /// Astigmatismo induzido pela incisão (D) e eixo da incisão (°).
    public var sia: Double = 0.10
    public var siaAxis: Double = 180
    /// Cilindro da LIO (plano da LIO) e eixo de alinhamento (°).
    public var iolCylinder: Double = 0
    public var iolAxis: Double = 90
    /// Razão de toricidade (LIO → plano corneano).
    public var ratio: Double = 1.46

    public init() {}
}

/// Resultado do planejamento tórico (`torState` + `toricRecalc` da web).
public struct ToricPlan: Sendable, Hashable {
    public let input: ToricInput
    /// Astigmatismo corneano total já somado ao SIA (vetor de duplo-ângulo).
    public let totalVector: AstigmatismVector
    public var totalMagnitude: Double { totalVector.magnitude }
    public var totalAxis: Double { totalVector.axis }
    /// Cilindro da LIO convertido ao plano corneano.
    public let iolAtCornealPlane: Double
    /// Residual previsto com o alinhamento escolhido.
    public let residualVector: AstigmatismVector
    public var residualMagnitude: Double { residualVector.magnitude }
    public var residualAxis: Double { residualVector.axis }
    /// Residual se a LIO ficasse exatamente no eixo do astigmatismo total.
    public let residualIfAligned: Double
    /// Desalinhamento (°) entre o eixo da LIO e o meridiano curvo total (0–90).
    public let misalignment: Double

    /// Fração aproximada da correção perdida pelo desalinhamento (≈3,3 % por grau).
    public var lostCorrectionPercent: Int { Int(PowerPlanner.roundHalfUp(misalignment * 3.3)) }
    /// Astigmatismo total abaixo de 0,75 D: normalmente não se indica tórica.
    public var belowToricThreshold: Bool { totalMagnitude < 0.75 }
    /// Cilindro no plano da LIO que anularia o astigmatismo total.
    public var idealIOLCylinder: Double { totalMagnitude * input.ratio }
}

public enum ToricPlanner {
    /// Faixa aceitável para a razão de toricidade calculada pela ELP do olho.
    public static let ratioRange = 1.0...2.2
    /// Razão de toricidade mínima aceita na entrada.
    public static let minimumRatio = 0.5

    public static func plan(_ raw: ToricInput) -> ToricPlan {
        var input = raw
        input.sia = max(0, raw.sia)
        input.iolCylinder = max(0, raw.iolCylinder)
        input.ratio = max(minimumRatio, raw.ratio)
        input.totalCylinder = max(0, raw.totalCylinder)

        var tca: AstigmatismVector
        if input.model == .total {
            tca = AstigmatismVector(magnitude: input.totalCylinder, axis: input.totalAxis)
        } else {
            let cyl: Double = if let k1 = input.k1, let k2 = input.k2 { abs(k2 - k1) } else { 0 }
            switch input.model {
            case .naeserSavini:
                tca = AstigmatismVector(magnitude: ToricRegression.naeserSavini(cylinder: cyl, axis: input.kAxis), axis: input.kAxis)
            case .abulafiaKoch:
                tca = ToricRegression.abulafiaKoch(AstigmatismVector(magnitude: cyl, axis: input.kAxis))
            default:
                tca = AstigmatismVector(magnitude: cyl, axis: input.kAxis)
            }
        }
        // A incisão aplana o próprio meridiano: o SIA entra com o meridiano curvo a 90° do eixo da incisão.
        // A soma parte de (+0, +0) como o `vAdd` da web: com astigmatismo nulo, −0 viraria eixo 90° no atan2.
        tca = .zero + tca + AstigmatismVector(magnitude: input.sia, axis: input.siaAxis + 90)

        let cc = input.iolCylinder / input.ratio
        let residual = tca - AstigmatismVector(magnitude: cc, axis: input.iolAxis)
        let taAxis = tca.axis
        let mis = abs((input.iolAxis - taAxis + 90 + 180).truncatingRemainder(dividingBy: 180) - 90)
        return ToricPlan(input: input, totalVector: tca, iolAtCornealPlane: cc, residualVector: residual,
                         residualIfAligned: abs(tca.magnitude - cc), misalignment: mis)
    }

    /// "Sugerir ideal": degrau da plataforma mais próximo de (astig. total × razão) e eixo no meridiano curvo.
    public static func suggestion(for plan: ToricPlan, platform: ToricPlatform) -> (cylinder: Double, axis: Double) {
        let need = plan.idealIOLCylinder
        var best = platform.steps[0]
        for s in platform.steps where abs(s - need) < abs(best - need) { best = s }
        return (best, PowerPlanner.roundHalfUp(plan.totalAxis))
    }

    /// Razão de toricidade pela ELP do olho (análise meridional, princípio do Barrett Toric): converte
    /// o cilindro da LIO ao plano corneano com a mesma vergência do cálculo esférico (SRK/T), usando
    /// a biometria real e o poder sugerido. `nil` fora da faixa de sanidade ou sem biometria.
    public static func toricityRatio(eye: EyeBiometry, effectiveA: Double, implantedPower: Double, iolCylinder: Double) -> Double? {
        let dc = max(1.0, iolCylinder == 0 ? 2.25 : iolCylinder) // cilindro representativo p/ a conversão
        let r1 = IOLFormulas.predictedRefraction(.srkt, eye: eye, aConstant: effectiveA, implantedPower: implantedPower - dc / 2)
        let r2 = IOLFormulas.predictedRefraction(.srkt, eye: eye, aConstant: effectiveA, implantedPower: implantedPower + dc / 2)
        let cylCorneal = abs(IOLFormulas.toCornealPlane(r1) - IOLFormulas.toCornealPlane(r2))
        guard cylCorneal > 0.05 else { return nil }
        let ratio = dc / cylCorneal
        return ratioRange.contains(ratio) ? ratio : nil
    }
}

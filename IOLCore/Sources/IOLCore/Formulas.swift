import Foundation

/// Fórmulas de cálculo de poder dióptrico disponíveis no app.
/// A ordem de `allCases` é a ordem de exibição (igual à versão web).
public enum FormulaKey: String, CaseIterable, Sendable, Codable, Identifiable {
    case srkt = "SRK/T"
    case t2 = "T2"
    case holladay1 = "Holladay 1"
    case holladay1WK = "Holladay 1 WK"
    case hofferQ = "Hoffer Q"
    case haigis = "Haigis"
    case castrop = "Castrop"

    public var id: String { rawValue }
}

/// Motor de fórmulas. Porte fiel do JavaScript da versão web (validado por
/// testes contra valores gerados pelo código original).
public enum IOLFormulas {
    /// Distância vértice usada para levar a refração-alvo ao plano corneano (mm).
    public static let vertexDistance = 12.0
    /// Acima deste comprimento axial (mm) a variante Holladay 1 com ajuste Wang-Koch fica disponível.
    public static let wangKochThreshold = 26.0

    /// Olho padrão usado para calibrar Haigis (a0) e Castrop (H) contra o SRK/T.
    static let standardEye = EyeBiometry(axialLength: 23.5, keratometry: 43.5, acd: 3.37, lensThickness: 4.7)

    @inline(__always)
    static func toCornealPlane(_ refraction: Double) -> Double {
        refraction / (1 - 0.001 * vertexDistance * refraction)
    }

    // MARK: - Fórmulas de 3ª geração

    public static func srkt(axialLength al: Double, keratometry k: Double, aConstant a: Double, target r: Double) -> Double {
        let ncm1 = 0.333
        let rad = 337.5 / k
        let lcor = al > 24.2 ? (-3.446 + 1.715 * al - 0.0237 * al * al) : al
        let cw = -5.41 + 0.58412 * lcor + 0.098 * k
        var disc = rad * rad - (cw * cw) / 4
        if disc < 0 { disc = 0 }
        let h = rad - disc.squareRoot()
        let acd = (0.62467 * a - 68.747) - 3.336 + h
        let l = al + (0.65696 - 0.02029 * al)
        let rx = toCornealPlane(r)
        let kc = 1000 * ncm1 / rad
        let v1 = kc + rx
        return (1336 / (l - acd)) - (1336 / (1336 / v1 - acd))
    }

    public static func holladay1(axialLength al: Double, keratometry k: Double, aConstant a: Double, target r: Double) -> Double {
        let sf = 0.5663 * a - 65.6
        let rad = 337.5 / k
        let ag = min(13.5, 12.5 * al / 23.45)
        var disc = rad * rad - (ag * ag) / 4
        if disc < 0 { disc = 0 }
        let aacd = 0.56 + rad - disc.squareRoot()
        let elp = aacd + sf
        let l = al + 0.2
        let kc = 1000 * (1.0 / 3.0) / rad
        let rx = toCornealPlane(r)
        let v1 = kc + rx
        return (1336 / (l - elp)) - (1336 / (1336 / v1 - elp))
    }

    public static func personalizedACD(fromAConstant a: Double) -> Double {
        0.58357 * a - 63.896
    }

    public static func hofferQ(axialLength al: Double, keratometry k: Double, aConstant a: Double, target r: Double) -> Double {
        let pacd = personalizedACD(fromAConstant: a)
        let alc = min(31, max(18.5, al))
        let m: Double = alc <= 23 ? 1 : -1
        let g: Double = alc <= 23 ? 28 : 23.5
        let tanK = tan(k * .pi / 180)
        let acd = pacd + 0.3 * (alc - 23.5) + tanK * tanK
            + (0.1 * m * pow(23.5 - alc, 2) * tan(0.1 * pow(g - alc, 2) * .pi / 180))
            - 0.99166
        let rx = toCornealPlane(r)
        return (1336 / (al - acd - 0.05)) - (1.336 / ((1.336 / (k + rx)) - ((acd + 0.05) / 1000)))
    }

    /// T2 (Sheard, Smith & Cooke 2010): SRK/T com a altura corneana substituída pela
    /// regressão H2 = -10.326 + 0.32630·AL + 0.13533·K (AL sem correção, evita o "cusp").
    public static func t2(axialLength al: Double, keratometry k: Double, aConstant a: Double, target r: Double) -> Double {
        let h = -10.326 + 0.32630 * al + 0.13533 * k
        let acd = (0.62467 * a - 68.747) - 3.336 + h
        let l = al + (0.65696 - 0.02029 * al)
        let rad = 337.5 / k
        let rx = toCornealPlane(r)
        let kc = 1000 * 0.333 / rad
        let v1 = kc + rx
        return (1336 / (l - acd)) - (1336 / (1336 / v1 - acd))
    }

    /// Wang-Koch modificado (2018) para Holladay 1: AL ajustado quando AL > 26 mm.
    public static func wangKochAxialLength(_ al: Double) -> Double {
        0.817 * al + 4.7013
    }

    public static func holladay1WangKoch(axialLength al: Double, keratometry k: Double, aConstant a: Double, target r: Double) -> Double {
        holladay1(axialLength: al > wangKochThreshold ? wangKochAxialLength(al) : al, keratometry: k, aConstant: a, target: r)
    }

    // MARK: - Castrop (Langenbucher 2021)

    /// Constantes da Castrop: córnea espessa (2 superfícies) e LIO fina.
    enum Castrop {
        static let c = 0.424
        static let r = 0.077
        static let nC = 1.376
        static let n = 1.336
        static let cct = 0.5
        static let liouBrennan = 6.40 / 7.77
    }

    static func castropRaw(axialLength al: Double, keratometry k: Double, h: Double, target rTarget: Double, acd acdPre: Double?, lensThickness lt: Double?) -> Double {
        let acd = usable(acdPre) ?? 3.37
        let ltu = usable(lt) ?? 4.7
        let rca = 337.5 / k
        let pca = (Castrop.nC - 1) * 1000 / rca
        let rcp = rca * Castrop.liouBrennan
        let pcp = (Castrop.n - Castrop.nC) * 1000 / rcp
        let elp = acd + Castrop.c * ltu + h
        let rc = toCornealPlane(rTarget - Castrop.r)
        var v = rc + pca
        v = v / (1 - (Castrop.cct / Castrop.nC / 1000) * v)
        v = v + pcp
        v = v / (1 - ((elp - Castrop.cct) / Castrop.n / 1000) * v)
        return 1000 * Castrop.n / (al - elp) - v
    }

    /// Calibra o offset H da Castrop para casar o SRK/T no olho padrão (bisseção).
    public static func castropH(aConstant a: Double) -> Double {
        let e = standardEye
        let target = srkt(axialLength: e.axialLength, keratometry: e.keratometry, aConstant: a, target: 0)
        var lo = -4.0, hi = 4.0
        for _ in 0..<60 {
            let mid = (lo + hi) / 2
            let p = castropRaw(axialLength: e.axialLength, keratometry: e.keratometry, h: mid, target: 0, acd: e.acd, lensThickness: e.lensThickness)
            if p > target { hi = mid } else { lo = mid }
        }
        return (lo + hi) / 2
    }

    public static func castrop(axialLength al: Double, keratometry k: Double, aConstant a: Double, target r: Double, acd: Double?, lensThickness lt: Double?) -> Double {
        castropRaw(axialLength: al, keratometry: k, h: castropH(aConstant: a), target: r, acd: acd, lensThickness: lt)
    }

    // MARK: - Haigis

    /// Haigis: a1 = 0,4 e a2 = 0,1 fixos; a0 calibrado por bisseção para casar a predição do
    /// SRK/T no olho padrão. Não usar a conversão "padrão" a0 = 0.62467·A − 72.434: ela iguala
    /// a ELP mas ignora as convenções da Haigis (índice 1,3315 e AL sem correção retiniana).
    public static func haigisA0(aConstant a: Double) -> Double {
        let e = standardEye
        let target = srkt(axialLength: e.axialLength, keratometry: e.keratometry, aConstant: a, target: 0)
        var lo = -3.0, hi = 5.0
        for _ in 0..<60 {
            let mid = (lo + hi) / 2
            let p = haigisRaw(axialLength: e.axialLength, keratometry: e.keratometry, a0: mid, a1: 0.4, a2: 0.1, target: 0, acd: e.acd)
            if p < target { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }

    static func haigisRaw(axialLength al: Double, keratometry k: Double, a0: Double, a1: Double, a2: Double, target r: Double, acd acdPre: Double?) -> Double {
        let acdUse = usable(acdPre) ?? 3.37
        let d = a0 + a1 * acdUse + a2 * al
        let rad = 337.5 / k
        let dc = (1.3315 - 1) * 1000 / rad
        let rx = toCornealPlane(r)
        let z = dc + rx
        let n = 1.336
        return (1000 * n / (al - d)) - (1000 * n / (1000 * n / z - d))
    }

    public static func haigis(axialLength al: Double, keratometry k: Double, aConstant a: Double, target r: Double, acd: Double?) -> Double {
        haigisRaw(axialLength: al, keratometry: k, a0: haigisA0(aConstant: a), a1: 0.4, a2: 0.1, target: r, acd: acd)
    }

    // MARK: - API unificada

    /// Poder da LIO (D) para a fórmula, o olho, a constante A e a refração-alvo (D, plano óculos).
    public static func power(_ formula: FormulaKey, eye: EyeBiometry, aConstant a: Double, target r: Double) -> Double {
        let al = eye.axialLength, k = eye.keratometry
        switch formula {
        case .srkt: return srkt(axialLength: al, keratometry: k, aConstant: a, target: r)
        case .t2: return t2(axialLength: al, keratometry: k, aConstant: a, target: r)
        case .holladay1: return holladay1(axialLength: al, keratometry: k, aConstant: a, target: r)
        case .holladay1WK: return holladay1WangKoch(axialLength: al, keratometry: k, aConstant: a, target: r)
        case .hofferQ: return hofferQ(axialLength: al, keratometry: k, aConstant: a, target: r)
        case .haigis: return haigis(axialLength: al, keratometry: k, aConstant: a, target: r, acd: eye.acd)
        case .castrop: return castrop(axialLength: al, keratometry: k, aConstant: a, target: r, acd: eye.acd, lensThickness: eye.lensThickness)
        }
    }

    /// Refração prevista (D) para um poder implantado, por inversão numérica da fórmula.
    public static func predictedRefraction(_ formula: FormulaKey, eye: EyeBiometry, aConstant a: Double, implantedPower p: Double) -> Double {
        var lo = -20.0, hi = 20.0
        for _ in 0..<60 {
            let mid = (lo + hi) / 2
            let calc = power(formula, eye: eye, aConstant: a, target: mid)
            if calc > p { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }

    /// Fórmulas aplicáveis ao olho (Holladay 1 WK só aparece em olhos longos).
    public static func activeFormulas(axialLength al: Double) -> [FormulaKey] {
        FormulaKey.allCases.filter { $0 != .holladay1WK || al > wangKochThreshold }
    }

    /// Fórmulas recomendadas conforme o comprimento axial.
    public static func recommendedFormulas(axialLength al: Double) -> [FormulaKey] {
        if al < 22 { return [.hofferQ, .haigis, .castrop] }
        if al > 26 { return [.holladay1WK, .t2, .haigis, .castrop] }
        return [.srkt, .t2, .holladay1, .hofferQ, .haigis, .castrop]
    }

    /// Replica a regra do JS: `null`, `NaN` ou valores ≤ 0 caem no padrão.
    @inline(__always)
    static func usable(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }
}

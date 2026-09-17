import Foundation

public enum LensCategory: String, Sendable, Codable, CaseIterable, Identifiable {
    case monofocal
    case enhancedMonofocal = "enhanced-monofocal"
    case edof
    case bifocal
    case trifocal
    case continuous

    public var id: String { rawValue }

    /// Nome do grupo no seletor de LIO.
    public var title: String {
        switch self {
        case .monofocal: return "Monofocais"
        case .enhancedMonofocal: return "Enhanced"
        case .edof: return "EDOF"
        case .bifocal: return "Bifocais"
        case .trifocal: return "Trifocais/Pentafocal"
        case .continuous: return "Contínua/CRV"
        }
    }

    /// Grau de disfotopsia típico da classe (para a LIO digitada à mão).
    public var typicalDysphotopsia: Int {
        switch self {
        case .monofocal, .enhancedMonofocal: return 0
        case .edof: return 1
        case .continuous: return 2
        case .bifocal, .trifocal: return 3
        }
    }
}

/// Uma LIO do catálogo: curva de defocus binocular publicada (logMAR, nos pontos de
/// `DefocusModel.defocusAxis`), constante A (SRK/T, biometria óptica) e grau de disfotopsia (0–3).
public struct IOLLens: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let name: String
    public let manufacturer: String
    public let category: LensCategory
    public let type: String
    public let colorHex: String
    public let aConstant: Double
    public let dysphotopsia: Int
    public let defocusValues: [Double]
    /// `true` quando a curva não é a publicada da lente, e sim a de uma lente parecida ou a média da classe.
    public let curveEstimated: Bool
    /// Origem da constante A e observações (registro, versões tórica, rótulo do fabricante).
    public let notes: String

    public init(id: String, name: String, manufacturer: String, category: LensCategory, type: String, colorHex: String,
                aConstant: Double, dysphotopsia: Int, defocusValues: [Double], curveEstimated: Bool = false, notes: String = "") {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.category = category
        self.type = type
        self.colorHex = colorHex
        self.aConstant = aConstant
        self.dysphotopsia = dysphotopsia
        self.defocusValues = defocusValues
        self.curveEstimated = curveEstimated
        self.notes = notes
    }

    /// Identificador da LIO digitada à mão ("Outra").
    public static let customID = "custom"
    public var isCustom: Bool { id == Self.customID }
}

/// Catálogo unificado. Constantes A para biometria óptica: valor do fabricante/IOLcon quando a lente é
/// recente; para as mais antigas, a SRK/T otimizada do ULIB (ocusoft.de/ulib), que costuma ficar
/// 0,3–0,5 acima do rótulo (o rótulo é para ultrassom). Curvas de defocus: publicadas pelos
/// fabricantes; nas marcadas `curveEstimated` a curva é a de uma lente da mesma classe.
/// Os ids das 20 lentes originais não mudam (casos salvos os referenciam).
public enum LensCatalog {
    public static let all: [IOLLens] = [
        // MARK: Referência
        IOLLens(id: "mono-standard", name: "Monofocal Esférica Padrão", manufacturer: "Referência", category: .monofocal, type: "Monofocal", colorHex: "#6b7280", aConstant: 118.0, dysphotopsia: 0, defocusValues: [0.35, 0.15, 0.02, 0.15, 0.3, 0.45, 0.6, 0.72, 0.82], notes: "Curva genérica de monofocal esférica; use para lentes sem dados."),

        // MARK: Alcon
        IOLLens(id: "acrysof-iq-sn60wf", name: "AcrySof IQ (SN60WF)", manufacturer: "Alcon", category: .monofocal, type: "Monofocal Asf.", colorHex: "#334155", aConstant: 119.0, dysphotopsia: 0, defocusValues: [0.28, 0.10, -0.02, 0.07, 0.20, 0.35, 0.50, 0.62, 0.72], notes: "A 119,0 óptica (ULIB, n = 5363; rótulo 118,7). Tórica SN6AT3–T9: mesma constante. Curva do braço-controle dos estudos da Vivity."),
        IOLLens(id: "clareon-mono", name: "Clareon Monofocal (CNA0T0/SY60WF)", manufacturer: "Alcon", category: .monofocal, type: "Monofocal Asf.", colorHex: "#1e293b", aConstant: 119.1, dysphotopsia: 0, defocusValues: [0.28, 0.10, -0.02, 0.07, 0.20, 0.35, 0.50, 0.62, 0.72], curveEstimated: true, notes: "A 119,1 óptica (fabricante). Tórica CNW0T3–T9 / AutonoMe CCA0T: mesma constante. Curva da AcrySof IQ (mesma óptica)."),
        IOLLens(id: "acrysof-sa60at", name: "AcrySof Esférica (SA60AT/SN60AT)", manufacturer: "Alcon", category: .monofocal, type: "Monofocal Esf.", colorHex: "#64748b", aConstant: 118.7, dysphotopsia: 0, defocusValues: [0.35, 0.15, 0.02, 0.15, 0.3, 0.45, 0.6, 0.72, 0.82], curveEstimated: true, notes: "A 118,7 óptica (fabricante; ULIB 118,8; rótulo 118,4). Curva genérica de esférica."),
        IOLLens(id: "acrysof-ma60ac", name: "AcrySof MA60AC (3 peças, sulco)", manufacturer: "Alcon", category: .monofocal, type: "Monofocal 3 pç", colorHex: "#94a3b8", aConstant: 118.9, dysphotopsia: 0, defocusValues: [0.35, 0.15, 0.02, 0.15, 0.3, 0.45, 0.6, 0.72, 0.82], curveEstimated: true, notes: "A 118,9 óptica no saco (ULIB 119,2; rótulo 118,4). No sulco, reduza ≈0,5–1,0 D o poder. Curva genérica."),
        IOLLens(id: "vivity", name: "Vivity (DFT015)", manufacturer: "Alcon", category: .edof, type: "EDOF", colorHex: "#ec4899", aConstant: 119.1, dysphotopsia: 1, defocusValues: [0.2, 0.07, -0.02, 0.03, 0.08, 0.15, 0.26, 0.38, 0.52], notes: "A 119,1 óptica (IOLcon; iolreference 119,2). Tórica DFT315–615: mesma constante. Não difrativa (X-Wave)."),
        IOLLens(id: "clareon-vivity", name: "Clareon Vivity (CNWET0)", manufacturer: "Alcon", category: .edof, type: "EDOF", colorHex: "#f472b6", aConstant: 119.1, dysphotopsia: 1, defocusValues: [0.2, 0.07, -0.02, 0.03, 0.08, 0.15, 0.26, 0.38, 0.52], notes: "Registro Anvisa 81869420138. Mesma óptica da Vivity AcrySof; tórica CNWET3–6."),
        IOLLens(id: "restor-sv25t0", name: "ReSTOR +2,5 (SV25T0)", manufacturer: "Alcon", category: .bifocal, type: "Bifocal apod.", colorHex: "#d97706", aConstant: 119.1, dysphotopsia: 2, defocusValues: [0.28, 0.10, 0.0, 0.08, 0.16, 0.14, 0.10, 0.18, 0.32], curveEstimated: true, notes: "A 119,1 (ULIB). Adição +2,5 D no plano da LIO (≈ −1,9 D no gráfico). Curva estimada a partir do estudo ReSTOR +2,5/+3,0 (Alcon)."),
        IOLLens(id: "restor-sn6ad1", name: "ReSTOR +3,0 (SN6AD1)", manufacturer: "Alcon", category: .bifocal, type: "Bifocal apod.", colorHex: "#b45309", aConstant: 118.9, dysphotopsia: 3, defocusValues: [0.3, 0.12, 0.01, 0.12, 0.24, 0.22, 0.14, 0.08, 0.16], notes: "A 118,9 (IOLcon; ULIB 119,0)."),
        IOLLens(id: "restor-sn6ad3", name: "ReSTOR +4,0 (SN6AD3)", manufacturer: "Alcon", category: .bifocal, type: "Bifocal apod.", colorHex: "#78350f", aConstant: 118.9, dysphotopsia: 3, defocusValues: [0.32, 0.13, 0.01, 0.15, 0.3, 0.38, 0.34, 0.18, 0.06], notes: "A 118,9 (IOLcon; ULIB 119,0)."),
        IOLLens(id: "panoptix", name: "PanOptix (TFNT00)", manufacturer: "Alcon", category: .trifocal, type: "Trifocal", colorHex: "#facc15", aConstant: 119.1, dysphotopsia: 3, defocusValues: [0.15, 0.04, -0.02, 0.02, 0.06, 0.08, 0.06, 0.04, 0.08], notes: "A 119,1 óptica (fabricante/ULIB). Tórica TFNT30–60: mesma constante."),
        IOLLens(id: "clareon-panoptix", name: "Clareon PanOptix (CNWTT0)", manufacturer: "Alcon", category: .trifocal, type: "Trifocal", colorHex: "#eab308", aConstant: 119.1, dysphotopsia: 3, defocusValues: [0.15, 0.04, -0.02, 0.02, 0.06, 0.08, 0.06, 0.04, 0.08], notes: "Mesma óptica da PanOptix AcrySof em material Clareon; tórica CNWTT3–6."),
        IOLLens(id: "clareon-panoptix-pro", name: "Clareon PanOptix Pro (PXYWT0)", manufacturer: "Alcon", category: .trifocal, type: "Trifocal", colorHex: "#ca8a04", aConstant: 119.1, dysphotopsia: 3, defocusValues: [0.14, 0.03, -0.03, 0.02, 0.05, 0.07, 0.05, 0.03, 0.07], curveEstimated: true, notes: "Registro Anvisa 81869420152 (tórica 81869420154). Difrativa com menos perda de luz (Enlighten NXT); curva estimada a partir da PanOptix."),

        // MARK: J&J Vision
        IOLLens(id: "tecnis-zcb00", name: "Tecnis 1 (ZCB00/DCB00)", manufacturer: "J&J Vision", category: .monofocal, type: "Monofocal Asf.", colorHex: "#1d4ed8", aConstant: 119.3, dysphotopsia: 0, defocusValues: [0.28, 0.10, -0.03, 0.08, 0.22, 0.38, 0.52, 0.64, 0.74], notes: "A 119,3 óptica (fabricante/ULIB). Tórica II ZCU150–600: mesma constante. Curva do braço-controle do estudo da Eyhance."),
        IOLLens(id: "sensar-ar40e", name: "Sensar AR40e (3 peças, sulco)", manufacturer: "J&J Vision", category: .monofocal, type: "Monofocal 3 pç", colorHex: "#60a5fa", aConstant: 118.7, dysphotopsia: 0, defocusValues: [0.35, 0.15, 0.02, 0.15, 0.3, 0.45, 0.6, 0.72, 0.82], curveEstimated: true, notes: "A 118,7 óptica no saco (ULIB; rótulo 118,4). No sulco, reduza ≈0,5–1,0 D o poder. Curva genérica."),
        IOLLens(id: "eyehance", name: "Eyhance (ICB00/DIB00)", manufacturer: "J&J Vision", category: .enhancedMonofocal, type: "Enhanced", colorHex: "#2563eb", aConstant: 119.3, dysphotopsia: 0, defocusValues: [0.18, 0.05, -0.04, 0.03, 0.13, 0.24, 0.38, 0.52, 0.65], notes: "A 119,3 óptica (fabricante). Tórica II DIU150–600: mesma constante."),
        IOLLens(id: "puresee", name: "PureSee (ZEN00V/DEN00V)", manufacturer: "J&J Vision", category: .edof, type: "EDOF", colorHex: "#0ea5e9", aConstant: 119.3, dysphotopsia: 1, defocusValues: [0.12, 0.02, -0.06, 0.01, 0.09, 0.16, 0.25, 0.37, 0.5], notes: "A 119,3 óptica (fabricante). EDOF puramente refrativa; tórica DET150–375."),
        IOLLens(id: "symfony", name: "Symfony (ZXR00 / DXR00V OptiBlue)", manufacturer: "J&J Vision", category: .edof, type: "EDOF", colorHex: "#84cc16", aConstant: 119.3, dysphotopsia: 2, defocusValues: [0.03, 0.01, 0, 0, 0.01, 0.05, 0.11, 0.21, 0.31], notes: "A 119,3 óptica (fabricante). ZXR00 descontinuada; DXR00V (OptiBlue) tem a mesma óptica. Tórica DXW150–375."),
        IOLLens(id: "synergy", name: "Synergy (ZFR00V/DFR00V)", manufacturer: "J&J Vision", category: .continuous, type: "EDOF+MF", colorHex: "#4f46e5", aConstant: 119.3, dysphotopsia: 3, defocusValues: [0.10, 0.02, -0.04, 0.0, 0.03, 0.05, 0.05, 0.05, 0.10], notes: "A 119,3 óptica (fabricante). Híbrida difrativa EDOF + multifocal; tórica DFW150–375. Curva do estudo do fabricante."),
        IOLLens(id: "odyssey", name: "Odyssey (DFR00V/DRN00V)", manufacturer: "J&J Vision", category: .continuous, type: "CRV", colorHex: "#6366f1", aConstant: 119.3, dysphotopsia: 2, defocusValues: [0.08, 0, -0.02, 0, 0.02, 0.04, 0.06, 0.1, 0.18], notes: "A 119,3 óptica (fabricante). Tórica II DRT150–375."),
        IOLLens(id: "tecnis-mf-zkb00", name: "Tecnis Multifocal +2,75 (ZKB00)", manufacturer: "J&J Vision", category: .bifocal, type: "Bifocal difr.", colorHex: "#f59e0b", aConstant: 119.3, dysphotopsia: 3, defocusValues: [0.30, 0.12, 0.0, 0.10, 0.22, 0.22, 0.12, 0.10, 0.20], curveEstimated: true, notes: "A 119,3 óptica (fabricante). Tórica ZKU. Curva estimada dos dados do fabricante."),
        IOLLens(id: "tecnis-mf-zlb00", name: "Tecnis Multifocal +3,25 (ZLB00)", manufacturer: "J&J Vision", category: .bifocal, type: "Bifocal difr.", colorHex: "#d97706", aConstant: 119.3, dysphotopsia: 3, defocusValues: [0.30, 0.12, 0.0, 0.12, 0.28, 0.30, 0.20, 0.08, 0.12], curveEstimated: true, notes: "A 119,3 óptica (fabricante). Tórica ZLU. Curva estimada dos dados do fabricante."),
        IOLLens(id: "tecnis-mf-zmb00", name: "Tecnis Multifocal +4,0 (ZMB00)", manufacturer: "J&J Vision", category: .bifocal, type: "Bifocal difr.", colorHex: "#b45309", aConstant: 119.3, dysphotopsia: 3, defocusValues: [0.32, 0.13, 0.0, 0.15, 0.32, 0.42, 0.38, 0.20, 0.06], curveEstimated: true, notes: "A 119,3 óptica (fabricante; ULIB 119,5). Curva estimada dos dados do fabricante."),

        // MARK: Zeiss
        IOLLens(id: "ct-lucia-621p", name: "CT LUCIA 621P/PY", manufacturer: "Zeiss", category: .monofocal, type: "Monofocal Asf.", colorHex: "#0f766e", aConstant: 119.7, dysphotopsia: 0, defocusValues: [0.27, 0.09, -0.02, 0.07, 0.20, 0.35, 0.50, 0.62, 0.72], curveEstimated: true, notes: "A 119,7 óptica (IOLcon otimizada, estudos 119,7–119,9; rótulo 120,2). Registro Anvisa 10332030126 (família CT LUCIA). Óptica asférica de aberração variável; curva de monofocal asférica."),
        IOLLens(id: "ct-asphina-409mp", name: "CT ASPHINA 409MP", manufacturer: "Zeiss", category: .monofocal, type: "Monofocal Asf.", colorHex: "#14b8a6", aConstant: 118.3, dysphotopsia: 0, defocusValues: [0.28, 0.10, 0.0, 0.08, 0.22, 0.36, 0.51, 0.66, 0.75], curveEstimated: true, notes: "A 118,3 óptica (ULIB, n = 662; rótulo 118,0). Tórica AT TORBI 709M: 118,3 (ULIB 118,5). Curva de monofocal asférica."),
        IOLLens(id: "at-lara", name: "AT LARA 829MP", manufacturer: "Zeiss", category: .edof, type: "EDOF", colorHex: "#059669", aConstant: 118.3, dysphotopsia: 2, defocusValues: [0.22, 0.08, -0.02, 0.03, 0.06, 0.1, 0.18, 0.27, 0.42], notes: "A 118,3 óptica (fabricante). Tórica AT LARA toric 929M."),
        IOLLens(id: "at-lisa-809m", name: "AT LISA 809M (+3,75)", manufacturer: "Zeiss", category: .bifocal, type: "Bifocal difr.", colorHex: "#fb923c", aConstant: 118.0, dysphotopsia: 3, defocusValues: [0.32, 0.13, 0.01, 0.15, 0.30, 0.36, 0.30, 0.14, 0.05], curveEstimated: true, notes: "A 118,0 óptica (ULIB, n = 334; rótulo 117,5). Tórica AT LISA toric 909M. Curva estimada de bifocal +3,75."),
        IOLLens(id: "elana", name: "AT ELANA 841P", manufacturer: "Zeiss", category: .trifocal, type: "Trifocal", colorHex: "#ef4444", aConstant: 119.5, dysphotopsia: 3, defocusValues: [0.18, 0.06, 0, 0.04, 0.09, 0.12, 0.11, 0.05, 0.09], notes: "A 119,5 óptica (fabricante)."),
        IOLLens(id: "at-lisa-tri", name: "AT LISA tri 839MP", manufacturer: "Zeiss", category: .trifocal, type: "Trifocal", colorHex: "#f59e0b", aConstant: 118.9, dysphotopsia: 3, defocusValues: [0.17, 0.05, -0.01, 0.03, 0.07, 0.13, 0.15, 0.08, 0.06], notes: "A 118,9 óptica (ULIB, dados da Zeiss; rótulo 118,3). Tórica AT LISA tri toric 939MP: 118,5 (ULIB)."),

        // MARK: HOYA
        IOLLens(id: "isert-251", name: "iSert 251/255", manufacturer: "HOYA", category: .monofocal, type: "Monofocal Asf.", colorHex: "#78716c", aConstant: 118.8, dysphotopsia: 0, defocusValues: [0.28, 0.10, 0.0, 0.08, 0.22, 0.36, 0.51, 0.66, 0.75], curveEstimated: true, notes: "A 118,8 óptica (ULIB, n = 319; rótulo 118,4). Curva da Vivinex XY1."),
        IOLLens(id: "vivinex-xy1", name: "Vivinex XY-1", manufacturer: "HOYA", category: .monofocal, type: "Monofocal Asf.", colorHex: "#475569", aConstant: 119.21, dysphotopsia: 0, defocusValues: [0.26, 0.1, 0, 0.08, 0.22, 0.36, 0.51, 0.66, 0.75], notes: "A 119,21 óptica (IOLcon). Tórica XY1A: mesma constante."),
        IOLLens(id: "impress", name: "Vivinex iMpress (XY1-EM)", manufacturer: "HOYA", category: .enhancedMonofocal, type: "Enhanced", colorHex: "#a855f7", aConstant: 119.21, dysphotopsia: 0, defocusValues: [0.17, 0.04, -0.04, 0.02, 0.11, 0.22, 0.36, 0.5, 0.63], notes: "A 119,21 óptica (IOLcon; mesma plataforma da XY1)."),
        IOLLens(id: "gemetric", name: "Vivinex Gemetric", manufacturer: "HOYA", category: .trifocal, type: "Trifocal", colorHex: "#db2777", aConstant: 118.99, dysphotopsia: 3, defocusValues: [0.16, 0.04, -0.05, 0.02, 0.08, 0.13, 0.12, 0.08, 0.1], notes: "A 118,99 óptica (IOLcon). Gemetric Plus (+3,5 D) usa a mesma constante."),

        // MARK: Rayner
        IOLLens(id: "rayone-aspheric", name: "RayOne Aspheric (RAO600C)", manufacturer: "Rayner", category: .monofocal, type: "Monofocal Asf.", colorHex: "#9a3412", aConstant: 118.6, dysphotopsia: 0, defocusValues: [0.28, 0.10, 0.0, 0.08, 0.22, 0.36, 0.51, 0.66, 0.75], curveEstimated: true, notes: "A 118,6 óptica (fabricante; rótulo 118,0). Tórica RAO610T. Curva de monofocal asférica."),
        IOLLens(id: "rayone-emv", name: "RayOne EMV (RAO200E)", manufacturer: "Rayner", category: .enhancedMonofocal, type: "Enhanced", colorHex: "#f97316", aConstant: 118.6, dysphotopsia: 0, defocusValues: [0.22, 0.07, -0.02, 0.04, 0.12, 0.24, 0.38, 0.52, 0.64], curveEstimated: true, notes: "A 118,6 óptica (fabricante). Desenhada para monovisão (aberração esférica positiva); tórica RAO210T. Curva estimada."),
        IOLLens(id: "rayone-trifocal", name: "RayOne Trifocal (RAO603F)", manufacturer: "Rayner", category: .trifocal, type: "Trifocal", colorHex: "#c2410c", aConstant: 118.6, dysphotopsia: 3, defocusValues: [0.18, 0.06, -0.02, 0.04, 0.10, 0.13, 0.10, 0.06, 0.10], curveEstimated: true, notes: "A 118,6 óptica (fabricante). Tórica RAO613T. Curva estimada dos dados do fabricante."),
        IOLLens(id: "galaxy", name: "RayOne Galaxy", manufacturer: "Rayner", category: .continuous, type: "Contínua", colorHex: "#ea580c", aConstant: 118.6, dysphotopsia: 2, defocusValues: [0.14, 0.05, -0.01, 0.02, 0.05, 0.08, 0.12, 0.17, 0.28], notes: "A 118,6 óptica (fabricante). Óptica espiral refrativa; tórica Galaxy Toric."),

        // MARK: BVI / PhysIOL
        IOLLens(id: "micropure", name: "Micropure 1.2.3", manufacturer: "PhysIOL / BVI", category: .monofocal, type: "Monofocal Asf.", colorHex: "#0d9488", aConstant: 119.4, dysphotopsia: 0, defocusValues: [0.28, 0.10, 0.0, 0.08, 0.22, 0.36, 0.51, 0.66, 0.75], curveEstimated: true, notes: "A 119,4 SRK/T (fabricante, estimada). Curva de monofocal asférica."),
        IOLLens(id: "isopure", name: "BVI Isopure 1.2.3", manufacturer: "BVI", category: .enhancedMonofocal, type: "Isofocal", colorHex: "#0d9488", aConstant: 119.4, dysphotopsia: 0, defocusValues: [0.18, 0.04, -0.04, 0.05, 0.14, 0.24, 0.38, 0.54, 0.68], notes: "A 119,4 SRK/T (fabricante)."),
        IOLLens(id: "finevision", name: "FineVision HP (POD F GF)", manufacturer: "PhysIOL / BVI", category: .trifocal, type: "Trifocal", colorHex: "#14b8a6", aConstant: 119.4, dysphotopsia: 3, defocusValues: [0.16, 0.04, -0.02, 0.04, 0.1, 0.12, 0.1, 0.05, 0.08], notes: "A 119,4 SRK/T (fabricante; iolreference 119,5). Tórica POD FT."),
        IOLLens(id: "finevision-triumf", name: "FineVision Triumf (POD L GF)", manufacturer: "PhysIOL / BVI", category: .trifocal, type: "Trifocal EDOF", colorHex: "#2dd4bf", aConstant: 119.4, dysphotopsia: 3, defocusValues: [0.15, 0.04, -0.03, 0.03, 0.08, 0.11, 0.10, 0.10, 0.16], curveEstimated: true, notes: "A 119,4 SRK/T (mesma plataforma da HP). Trifocal com perfil EDOF (menos perto que a HP); curva estimada."),

        // MARK: Bausch + Lomb
        IOLLens(id: "envista-mx60e", name: "enVista (MX60E/MX60PL)", manufacturer: "Bausch + Lomb", category: .monofocal, type: "Monofocal Asf.", colorHex: "#7c2d12", aConstant: 119.1, dysphotopsia: 0, defocusValues: [0.28, 0.10, 0.0, 0.08, 0.22, 0.36, 0.51, 0.66, 0.75], curveEstimated: true, notes: "A 119,1 óptica (fabricante; rótulo 118,7). Aberração esférica neutra; tórica MX60ET/PT. Curva de monofocal asférica."),
        IOLLens(id: "envista-aspire", name: "enVista Aspire (EA)", manufacturer: "Bausch + Lomb", category: .enhancedMonofocal, type: "Enhanced", colorHex: "#c2410c", aConstant: 119.1, dysphotopsia: 0, defocusValues: [0.19, 0.05, -0.03, 0.03, 0.13, 0.25, 0.39, 0.53, 0.66], curveEstimated: true, notes: "A 119,1 óptica (fabricante). Zona central de 1,5 mm na face posterior; tórica ETA. Curva estimada (classe enhanced)."),
        IOLLens(id: "envista-envy", name: "enVista Envy (EN)", manufacturer: "Bausch + Lomb", category: .trifocal, type: "Trifocal", colorHex: "#ea580c", aConstant: 119.5, dysphotopsia: 3, defocusValues: [0.16, 0.04, -0.02, 0.03, 0.08, 0.11, 0.09, 0.05, 0.09], curveEstimated: true, notes: "A 119,5 óptica (fabricante). Difrativa posterior, adições +1,6/+3,1 D; tórica ETN. Curva estimada dos dados do fabricante."),
        IOLLens(id: "akreos-mi60", name: "Akreos MICS (MI60)", manufacturer: "Bausch + Lomb", category: .monofocal, type: "Monofocal Asf.", colorHex: "#a16207", aConstant: 119.1, dysphotopsia: 0, defocusValues: [0.28, 0.10, 0.0, 0.08, 0.22, 0.36, 0.51, 0.66, 0.75], curveEstimated: true, notes: "A 119,1 óptica (fabricante/ULIB; rótulo 118,4). Hidrofílica, 4 alças; Akreos AO (A060): 118,5. Curva de monofocal asférica."),

        // MARK: Hanita
        IOLLens(id: "seelens-af", name: "SeeLens AF", manufacturer: "Hanita", category: .monofocal, type: "Monofocal Asf.", colorHex: "#fb923c", aConstant: 118.8, dysphotopsia: 0, defocusValues: [0.28, 0.10, 0.0, 0.08, 0.22, 0.36, 0.51, 0.66, 0.75], curveEstimated: true, notes: "A 118,8 óptica (ULIB; rótulo 119,0). Tórica SeeLens Toric. Curva de monofocal asférica."),
        IOLLens(id: "hanita-extend", name: "Hanita Extend", manufacturer: "Hanita", category: .enhancedMonofocal, type: "Enhanced", colorHex: "#f97316", aConstant: 118.5, dysphotopsia: 1, defocusValues: [0.22, 0.08, 0, 0.06, 0.12, 0.2, 0.35, 0.5, 0.62], notes: "A 118,5 óptica (fabricante)."),
        IOLLens(id: "hanita-intensity", name: "Hanita Intensity SL", manufacturer: "Hanita", category: .trifocal, type: "Pentafocal", colorHex: "#7c3aed", aConstant: 118.4, dysphotopsia: 3, defocusValues: [0.3, 0.1, -0.02, 0.05, 0.08, 0.1, 0.1, 0.12, 0.22], notes: "A 118,4 óptica (fabricante)."),

        // MARK: Mediphacos (Brasil)
        IOLLens(id: "mediphacos-mfr2", name: "Mediphacos MFR2", manufacturer: "Mediphacos", category: .monofocal, type: "Monofocal Asf.", colorHex: "#15803d", aConstant: 118.11, dysphotopsia: 0, defocusValues: [0.28, 0.10, 0.0, 0.08, 0.22, 0.36, 0.51, 0.66, 0.75], curveEstimated: true, notes: "Registro Anvisa 10161020020. A 118,11 SRK/T (fabricante). Acrílico híbrido Flexacryl, aberração esférica neutra. Curva de monofocal asférica."),
        IOLLens(id: "mediphacos-una", name: "Mediphacos UnA (UnA5)", manufacturer: "Mediphacos", category: .monofocal, type: "Monofocal Asf.", colorHex: "#16a34a", aConstant: 118.2, dysphotopsia: 0, defocusValues: [0.28, 0.10, 0.0, 0.08, 0.22, 0.36, 0.51, 0.66, 0.75], curveEstimated: true, notes: "Registro Anvisa 10161020061. A 118,20 SRK/T (fabricante; rótulo 118,0). Hidrofílica, saco ou sulco. Curva de monofocal asférica."),
        IOLLens(id: "mediphacos-bios", name: "Mediphacos BIOS Trifocal", manufacturer: "Mediphacos", category: .trifocal, type: "Trifocal", colorHex: "#22c55e", aConstant: 118.2, dysphotopsia: 3, defocusValues: [0.18, 0.06, -0.01, 0.04, 0.10, 0.14, 0.12, 0.07, 0.10], curveEstimated: true, notes: "A 118,20 SRK/T óptica (fabricante; 118,0 ultrassom; Barrett LF 1,46). Difrativa posterior, adições +1,5/+3,0 D. Curva estimada (classe trifocal)."),

        // MARK: Medicontur
        IOLLens(id: "biflex-677ab", name: "Bi-Flex 677AB", manufacturer: "Medicontur", category: .monofocal, type: "Monofocal Asf.", colorHex: "#0e7490", aConstant: 118.0, dysphotopsia: 0, defocusValues: [0.28, 0.10, 0.0, 0.08, 0.22, 0.36, 0.51, 0.66, 0.75], curveEstimated: true, notes: "A 118,0 óptica (ULIB, n = 103, = rótulo). Hidrofílica; tórica 677TAB. Curva de monofocal asférica."),
        IOLLens(id: "liberty-677my", name: "Liberty 677MY", manufacturer: "Medicontur", category: .trifocal, type: "Trifocal", colorHex: "#0891b2", aConstant: 118.0, dysphotopsia: 3, defocusValues: [0.18, 0.06, -0.01, 0.04, 0.10, 0.13, 0.11, 0.07, 0.10], curveEstimated: true, notes: "A 118,0 óptica (rótulo, mesma plataforma da Bi-Flex; sem dado ULIB). Tórica 677TMY. Curva estimada (classe trifocal)."),

        // MARK: Teleon (Oculentis)
        IOLLens(id: "lentis-mplus-mf30", name: "Lentis Mplus MF30 (LS-313)", manufacturer: "Teleon", category: .bifocal, type: "Bifocal segm.", colorHex: "#be185d", aConstant: 118.5, dysphotopsia: 2, defocusValues: [0.28, 0.10, 0.0, 0.08, 0.18, 0.20, 0.14, 0.12, 0.22], curveEstimated: true, notes: "A 118,5 óptica (ULIB, n = 239; rótulo 118,0). Segmentar refrativa +3,0 D; tórica MF30T. Curva estimada dos dados publicados."),

        // MARK: Ophtec
        IOLLens(id: "precizon-presbyopic", name: "Precizon Presbyopic NVA", manufacturer: "Ophtec", category: .bifocal, type: "Bifocal CTF", colorHex: "#9333ea", aConstant: 118.5, dysphotopsia: 2, defocusValues: [0.26, 0.09, 0.0, 0.07, 0.15, 0.18, 0.14, 0.14, 0.24], curveEstimated: true, notes: "A 118,5 óptica (ULIB do Precizon monofocal 560; rótulo 118,0). Refrativa de transição contínua (CTF), +2,75 D; tórica Presbyopic Toric. Curva estimada."),

        // MARK: Aurolab e Biotech (Índia)
        IOLLens(id: "aurovue", name: "Aurovue (FH5600AS)", manufacturer: "Aurolab", category: .monofocal, type: "Monofocal Asf.", colorHex: "#4d7c0f", aConstant: 118.0, dysphotopsia: 0, defocusValues: [0.28, 0.10, 0.0, 0.08, 0.22, 0.36, 0.51, 0.66, 0.75], curveEstimated: true, notes: "A 118,0 (rótulo; ULIB 117,8, n = 99). Hidrofóbica. Curva de monofocal asférica."),
        IOLLens(id: "aurovue-dfine", name: "Aurovue Dfine (trifocal)", manufacturer: "Aurolab", category: .trifocal, type: "Trifocal", colorHex: "#65a30d", aConstant: 118.0, dysphotopsia: 3, defocusValues: [0.20, 0.07, 0.0, 0.05, 0.11, 0.15, 0.13, 0.08, 0.11], curveEstimated: true, notes: "A 118,0 (rótulo; sem dado ULIB). Difrativa; curva estimada (classe trifocal)."),
        IOLLens(id: "eyecryl-plus", name: "Eyecryl Plus (ASHFY600)", manufacturer: "Biotech Vision", category: .monofocal, type: "Monofocal Asf.", colorHex: "#3f6212", aConstant: 118.6, dysphotopsia: 0, defocusValues: [0.28, 0.10, 0.0, 0.08, 0.22, 0.36, 0.51, 0.66, 0.75], curveEstimated: true, notes: "A 118,6 óptica (ULIB; rótulo 118,5). Hidrofóbica; Eyecryl Toric: 118,7. Curva de monofocal asférica."),
        IOLLens(id: "eyecryl-actv", name: "Eyecryl ACTV (+3,0)", manufacturer: "Biotech Vision", category: .bifocal, type: "Bifocal difr.", colorHex: "#84cc16", aConstant: 118.7, dysphotopsia: 3, defocusValues: [0.30, 0.12, 0.01, 0.12, 0.24, 0.22, 0.14, 0.08, 0.16], curveEstimated: true, notes: "A 118,7 óptica (ULIB; rótulo 118,5). Curva estimada (bifocal +3,0)."),
    ]

    public static let byID: [String: IOLLens] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func lens(id: String) -> IOLLens? { byID[id] }

    /// Favoritas de fábrica: as 20 lentes da versão original do catálogo, na ordem de então.
    public static let defaultFavorites: [String] = [
        "mono-standard", "vivinex-xy1", "eyehance", "impress", "isopure", "hanita-extend", "puresee", "symfony", "at-lara", "vivity",
        "restor-sn6ad1", "restor-sn6ad3", "gemetric", "elana", "at-lisa-tri", "panoptix", "finevision", "hanita-intensity", "odyssey", "galaxy",
    ]

    /// Fabricantes na ordem do catálogo (para a lista de configurações).
    public static let manufacturers: [String] = {
        var seen: [String] = []
        for l in all where !seen.contains(l.manufacturer) { seen.append(l.manufacturer) }
        return seen
    }()

    /// Curva de referência de uma classe: média das curvas publicadas (não estimadas) da classe.
    /// Serve para a LIO digitada à mão ("Outra").
    public static func referenceCurve(for category: LensCategory) -> [Double] {
        let published = all.filter { $0.category == category && !$0.curveEstimated }
        let pool = published.isEmpty ? all.filter { $0.category == category } : published
        guard let n = pool.first?.defocusValues.count, !pool.isEmpty else { return all[0].defocusValues }
        return (0..<n).map { i in pool.map { $0.defocusValues[i] }.reduce(0, +) / Double(pool.count) }
    }

    /// LIO digitada à mão: nome, classe (define a curva e a disfotopsia) e constante A.
    public static func custom(name: String, category: LensCategory, aConstant: Double) -> IOLLens {
        IOLLens(id: IOLLens.customID, name: name.isEmpty ? "Outra LIO" : name, manufacturer: "Outra", category: category,
                type: category.title, colorHex: "#0f172a", aConstant: aConstant, dysphotopsia: category.typicalDysphotopsia,
                defocusValues: referenceCurve(for: category), curveEstimated: true,
                notes: "Constante A digitada; curva média da classe \(category.title).")
    }
}

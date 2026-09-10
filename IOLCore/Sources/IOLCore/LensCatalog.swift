import Foundation

public enum LensCategory: String, Sendable, Codable, CaseIterable {
    case monofocal
    case enhancedMonofocal = "enhanced-monofocal"
    case edof
    case bifocal
    case trifocal
    case continuous
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

    public init(id: String, name: String, manufacturer: String, category: LensCategory, type: String, colorHex: String, aConstant: Double, dysphotopsia: Int, defocusValues: [Double]) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.category = category
        self.type = type
        self.colorHex = colorHex
        self.aConstant = aConstant
        self.dysphotopsia = dysphotopsia
        self.defocusValues = defocusValues
    }
}

/// Catálogo unificado. Constantes A conferidas contra IOLcon.org em 08/2026 (valores do
/// fabricante para biometria óptica). Ver observações por lente na versão web.
public enum LensCatalog {
    public static let all: [IOLLens] = [
        IOLLens(id: "mono-standard", name: "Monofocal Esférica Padrão", manufacturer: "Referência", category: .monofocal, type: "Monofocal", colorHex: "#6b7280", aConstant: 118.0, dysphotopsia: 0, defocusValues: [0.35, 0.15, 0.02, 0.15, 0.3, 0.45, 0.6, 0.72, 0.82]),
        IOLLens(id: "vivinex-xy1", name: "Vivinex XY-1", manufacturer: "HOYA", category: .monofocal, type: "Monofocal Asf.", colorHex: "#475569", aConstant: 119.21, dysphotopsia: 0, defocusValues: [0.26, 0.1, 0, 0.08, 0.22, 0.36, 0.51, 0.66, 0.75]),
        IOLLens(id: "eyehance", name: "Eyhance (ICB00)", manufacturer: "J&J Vision", category: .enhancedMonofocal, type: "Enhanced", colorHex: "#2563eb", aConstant: 119.3, dysphotopsia: 0, defocusValues: [0.18, 0.05, -0.04, 0.03, 0.13, 0.24, 0.38, 0.52, 0.65]),
        IOLLens(id: "impress", name: "Vivinex iMpress (XY1-EM)", manufacturer: "HOYA", category: .enhancedMonofocal, type: "Enhanced", colorHex: "#a855f7", aConstant: 119.21, dysphotopsia: 0, defocusValues: [0.17, 0.04, -0.04, 0.02, 0.11, 0.22, 0.36, 0.5, 0.63]),
        IOLLens(id: "isopure", name: "BVI Isopure 1.2.3", manufacturer: "BVI", category: .enhancedMonofocal, type: "Isofocal", colorHex: "#0d9488", aConstant: 119.4, dysphotopsia: 0, defocusValues: [0.18, 0.04, -0.04, 0.05, 0.14, 0.24, 0.38, 0.54, 0.68]),
        IOLLens(id: "hanita-extend", name: "Hanita Extend", manufacturer: "Hanita", category: .enhancedMonofocal, type: "Enhanced", colorHex: "#f97316", aConstant: 118.5, dysphotopsia: 1, defocusValues: [0.22, 0.08, 0, 0.06, 0.12, 0.2, 0.35, 0.5, 0.62]),
        IOLLens(id: "puresee", name: "PureSee (ZEN00V)", manufacturer: "J&J Vision", category: .edof, type: "EDOF", colorHex: "#0ea5e9", aConstant: 119.3, dysphotopsia: 1, defocusValues: [0.12, 0.02, -0.06, 0.01, 0.09, 0.16, 0.25, 0.37, 0.5]),
        IOLLens(id: "symfony", name: "Symfony (ZXR00)", manufacturer: "J&J Vision", category: .edof, type: "EDOF", colorHex: "#84cc16", aConstant: 119.3, dysphotopsia: 2, defocusValues: [0.03, 0.01, 0, 0, 0.01, 0.05, 0.11, 0.21, 0.31]),
        IOLLens(id: "at-lara", name: "AT LARA 829MP", manufacturer: "Zeiss", category: .edof, type: "EDOF", colorHex: "#059669", aConstant: 118.3, dysphotopsia: 2, defocusValues: [0.22, 0.08, -0.02, 0.03, 0.06, 0.1, 0.18, 0.27, 0.42]),
        IOLLens(id: "vivity", name: "Vivity (DFT015)", manufacturer: "Alcon", category: .edof, type: "EDOF", colorHex: "#ec4899", aConstant: 119.1, dysphotopsia: 1, defocusValues: [0.2, 0.07, -0.02, 0.03, 0.08, 0.15, 0.26, 0.38, 0.52]),
        IOLLens(id: "restor-sn6ad1", name: "ReSTOR +3,0 (SN6AD1)", manufacturer: "Alcon", category: .bifocal, type: "Bifocal apod.", colorHex: "#b45309", aConstant: 118.9, dysphotopsia: 3, defocusValues: [0.3, 0.12, 0.01, 0.12, 0.24, 0.22, 0.14, 0.08, 0.16]),
        IOLLens(id: "restor-sn6ad3", name: "ReSTOR +4,0 (SN6AD3)", manufacturer: "Alcon", category: .bifocal, type: "Bifocal apod.", colorHex: "#78350f", aConstant: 118.9, dysphotopsia: 3, defocusValues: [0.32, 0.13, 0.01, 0.15, 0.3, 0.38, 0.34, 0.18, 0.06]),
        IOLLens(id: "gemetric", name: "Vivinex Gemetric", manufacturer: "HOYA", category: .trifocal, type: "Trifocal", colorHex: "#db2777", aConstant: 118.99, dysphotopsia: 3, defocusValues: [0.16, 0.04, -0.05, 0.02, 0.08, 0.13, 0.12, 0.08, 0.1]),
        IOLLens(id: "elana", name: "AT ELANA 841P", manufacturer: "Zeiss", category: .trifocal, type: "Trifocal", colorHex: "#ef4444", aConstant: 119.5, dysphotopsia: 3, defocusValues: [0.18, 0.06, 0, 0.04, 0.09, 0.12, 0.11, 0.05, 0.09]),
        IOLLens(id: "at-lisa-tri", name: "AT LISA tri 839MP", manufacturer: "Zeiss", category: .trifocal, type: "Trifocal", colorHex: "#f59e0b", aConstant: 118.9, dysphotopsia: 3, defocusValues: [0.17, 0.05, -0.01, 0.03, 0.07, 0.13, 0.15, 0.08, 0.06]),
        IOLLens(id: "panoptix", name: "PanOptix (TFNT00)", manufacturer: "Alcon", category: .trifocal, type: "Trifocal", colorHex: "#facc15", aConstant: 119.1, dysphotopsia: 3, defocusValues: [0.15, 0.04, -0.02, 0.02, 0.06, 0.08, 0.06, 0.04, 0.08]),
        IOLLens(id: "finevision", name: "FineVision HP (POD F GF)", manufacturer: "PhysIOL / BVI", category: .trifocal, type: "Trifocal", colorHex: "#14b8a6", aConstant: 119.4, dysphotopsia: 3, defocusValues: [0.16, 0.04, -0.02, 0.04, 0.1, 0.12, 0.1, 0.05, 0.08]),
        IOLLens(id: "hanita-intensity", name: "Hanita Intensity SL", manufacturer: "Hanita", category: .trifocal, type: "Pentafocal", colorHex: "#7c3aed", aConstant: 118.4, dysphotopsia: 3, defocusValues: [0.3, 0.1, -0.02, 0.05, 0.08, 0.1, 0.1, 0.12, 0.22]),
        IOLLens(id: "odyssey", name: "Odyssey (DFR00V)", manufacturer: "J&J Vision", category: .continuous, type: "CRV", colorHex: "#6366f1", aConstant: 119.3, dysphotopsia: 2, defocusValues: [0.08, 0, -0.02, 0, 0.02, 0.04, 0.06, 0.1, 0.18]),
        IOLLens(id: "galaxy", name: "RayOne Galaxy", manufacturer: "Rayner", category: .continuous, type: "Contínua", colorHex: "#ea580c", aConstant: 118.6, dysphotopsia: 2, defocusValues: [0.14, 0.05, -0.01, 0.02, 0.05, 0.08, 0.12, 0.17, 0.28]),
    ]

    public static let byID: [String: IOLLens] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func lens(id: String) -> IOLLens? { byID[id] }
}

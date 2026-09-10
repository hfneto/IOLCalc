import Foundation

/// Biometria de um olho, no formato que as fórmulas consomem.
/// `acd` e `lensThickness` são opcionais: Haigis e Castrop usam valores padrão
/// (3,37 mm e 4,7 mm) quando ausentes, exatamente como a versão web.
public struct EyeBiometry: Sendable, Hashable, Codable {
    /// Comprimento axial (mm).
    public var axialLength: Double
    /// Ceratometria média (D), índice 1,3375.
    public var keratometry: Double
    /// Profundidade da câmara anterior pré-operatória (mm), do epitélio.
    public var acd: Double?
    /// Espessura do cristalino (mm).
    public var lensThickness: Double?
    /// Paquimetria central (µm). Refina a Castrop; ausente → 500 µm.
    public var centralCornealThickness: Double?

    public init(axialLength: Double, keratometry: Double, acd: Double? = nil, lensThickness: Double? = nil, centralCornealThickness: Double? = nil) {
        self.axialLength = axialLength
        self.keratometry = keratometry
        self.acd = acd
        self.lensThickness = lensThickness
        self.centralCornealThickness = centralCornealThickness
    }
}

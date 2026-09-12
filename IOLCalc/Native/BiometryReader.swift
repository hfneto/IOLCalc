import Foundation
import ImageIO
import Observation
import UniformTypeIdentifiers
import CoreGraphics

/// Um arquivo escolhido pelo usuário (foto, imagem ou PDF do laudo).
struct PickedFile: Sendable {
    let data: Data
    let name: String
    let type: UTType?
}

extension AIReadRequest {
    init(model: String, isPDF: Bool, mediaType: String, data: String) {
        self.model = model
        self.isPDF = isPDF
        self.mediaType = mediaType
        self.data = data
    }
}

/// Prepara o arquivo para a API, como o `prepareUpload` da web: PDF segue como está; imagens são
/// redimensionadas (máx. 2600 px no maior lado, respeitando a orientação EXIF) e recomprimidas em
/// JPEG até o base64 caber em ~5 MB.
enum UploadPrep {
    static let maxDimension = 2600
    static let maxBase64 = 5_000_000

    static func prepare(_ file: PickedFile, model: String) -> AIReadRequest {
        let isPDF = file.type?.conforms(to: .pdf) == true
            || file.name.lowercased().hasSuffix(".pdf")
            || file.data.starts(with: [0x25, 0x50, 0x44, 0x46]) // %PDF
        if isPDF {
            return AIReadRequest(model: model, isPDF: true, mediaType: "application/pdf", data: file.data.base64EncodedString())
        }
        guard let source = CGImageSourceCreateWithData(file.data as CFData, nil) else {
            let mt = file.type?.preferredMIMEType ?? "image/jpeg"
            return AIReadRequest(model: model, isPDF: false, mediaType: mt.hasPrefix("image/") ? mt : "image/jpeg",
                                 data: file.data.base64EncodedString())
        }
        var maxPixels = maxDimension
        var quality = 0.9
        var out = encodeJPEG(source, maxPixels: maxPixels, quality: quality) ?? file.data.base64EncodedString()
        // baixa a qualidade e, se preciso, a resolução até caber
        var guardCount = 0
        while out.count > maxBase64, guardCount < 12 {
            guardCount += 1
            if quality > 0.45 {
                quality -= 0.12
            } else {
                maxPixels = Int(Double(maxPixels) * 0.82)
                quality = 0.82
                if maxPixels < 500 { break }
            }
            if let next = encodeJPEG(source, maxPixels: maxPixels, quality: quality) { out = next }
        }
        return AIReadRequest(model: model, isPDF: false, mediaType: "image/jpeg", data: out)
    }

    /// Miniatura já com a orientação aplicada, sobre fundo branco, codificada em JPEG (base64).
    private static func encodeJPEG(_ source: CGImageSource, maxPixels: Int, quality: Double) -> String? {
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceShouldCache: false,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) else { return nil }
        let w = thumb.width, h = thumb.height
        guard w > 0, h > 0,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.draw(thumb, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let flat = ctx.makeImage() else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, flat, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return (data as Data).base64EncodedString()
    }
}

/// Biometria extraída pela IA de um ou mais laudos (mesmo JSON que a página web recebe).
struct BiometryReport: Equatable {
    static let numericKeys = ["AL", "K1", "K2", "ACD", "LT", "WTW", "CCT", "K2_axis", "TK1", "TK2", "TK2_axis"]
    /// Faixas plausíveis por parâmetro (para alertar sobre leitura suspeita).
    static let ranges: [(String, ClosedRange<Double>)] = [
        ("AL", 18...38), ("K1", 30...60), ("K2", 30...60), ("ACD", 1.5...5.5), ("LT", 2.5...7.0),
        ("WTW", 9...14), ("CCT", 380...720), ("TK1", 30...60), ("TK2", 30...60),
    ]

    var name: String?
    var od: [String: Double] = [:]
    var oe: [String: Double] = [:]

    subscript(eye: Eye) -> [String: Double] {
        get { eye == .od ? od : oe }
        set { if eye == .od { od = newValue } else { oe = newValue } }
    }

    /// Extrai o primeiro objeto JSON do texto da IA.
    static func parse(_ text: String) throws -> BiometryReport {
        guard let open = text.firstIndex(of: "{"), let close = text.lastIndex(of: "}"), open < close else {
            throw ReadError.noJSON(String(text.prefix(200)))
        }
        let json = String(text[open...close])
        guard let obj = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] else {
            throw ReadError.noJSON(String(text.prefix(200)))
        }
        var r = BiometryReport()
        if let n = obj["name"] as? String, !n.trimmingCharacters(in: .whitespaces).isEmpty {
            r.name = n.trimmingCharacters(in: .whitespaces)
        }
        for eye in Eye.allCases {
            let e = obj[eye.rawValue] as? [String: Any] ?? [:]
            var vals: [String: Double] = [:]
            for key in numericKeys {
                if let v = number(e[key]) { vals[key] = v }
            }
            r[eye] = vals
        }
        return r
    }

    private static func number(_ any: Any?) -> Double? {
        if let n = any as? NSNumber { return n.doubleValue.isFinite ? n.doubleValue : nil }
        if let s = any as? String { return Num.parse(s) }
        return nil
    }

    /// Mescla outro laudo: o primeiro valor não nulo de cada campo vence (como a web).
    mutating func merge(_ other: BiometryReport) {
        if name == nil, let n = other.name { name = n }
        for eye in Eye.allCases {
            var mine = self[eye]
            for (k, v) in other[eye] where mine[k] == nil { mine[k] = v }
            self[eye] = mine
        }
    }

    var isEmpty: Bool { od.isEmpty && oe.isEmpty && name == nil }

    /// Avisos de valores fora das faixas plausíveis ou ΔK muito alto.
    func warnings() -> [String] {
        var msgs: [String] = []
        for eye in Eye.allCases {
            let e = self[eye]
            for (k, range) in Self.ranges {
                guard let v = e[k] else { continue }
                if !range.contains(v) {
                    msgs.append("\(eye.rawValue) \(k)=\(Num.fmt(v, k == "CCT" ? 0 : 2)) (faixa esperada \(Num.fmt(range.lowerBound, 0))–\(Num.fmt(range.upperBound, 0)))")
                }
            }
            if let k1 = e["K1"], let k2 = e["K2"], abs(k2 - k1) > 8 {
                msgs.append("\(eye.rawValue) ΔK=\(Num.fmt(abs(k2 - k1))) D muito alto — confira K1/K2")
            }
        }
        return msgs
    }

    enum ReadError: LocalizedError {
        case noJSON(String)
        case noFiles
        var errorDescription: String? {
            switch self {
            case .noJSON(let t): return "Resposta sem JSON: \(t)"
            case .noFiles: return "Selecione uma foto ou PDF do laudo."
            }
        }
    }
}

/// Estado da leitura por IA na tela nativa: modelo escolhido, chave presente, progresso e mensagem.
@MainActor
@Observable
final class AIReaderState {
    struct Status: Equatable {
        enum Kind { case info, ok, error }
        var kind: Kind
        var text: String
        var details: [String] = []
    }

    static let models: [(id: String, title: String)] = [
        ("claude-sonnet-5", "claude-sonnet-5 (recomendado)"),
        ("claude-opus-5", "claude-opus-5 (mais preciso)"),
        ("claude-haiku-4-5-20251001", "claude-haiku-4-5 (mais rápido)"),
    ]
    private static let modelKey = "iol_model"

    var model: String { didSet { UserDefaults.standard.set(model, forKey: Self.modelKey) } }
    var hasKey = APIKeyStore.load() != nil
    var busy = false
    var status: Status?

    init() {
        model = UserDefaults.standard.string(forKey: Self.modelKey) ?? AIReader.defaultModel
    }

    func refreshKey() { hasKey = APIKeyStore.load() != nil }

    /// Lê um ou mais arquivos com a IA e preenche a biometria do modelo.
    func read(_ files: [PickedFile], into calc: CalculatorModel) async {
        guard !busy else { return }
        guard !files.isEmpty else { status = Status(kind: .error, text: BiometryReport.ReadError.noFiles.localizedDescription); return }
        refreshKey()
        guard let key = APIKeyStore.load() else {
            status = Status(kind: .error, text: "Configure a chave da API da Anthropic (Leitura por IA · avançado › Configurar chave).")
            return
        }
        busy = true
        defer { busy = false }
        do {
            var merged = BiometryReport()
            for (i, file) in files.enumerated() {
                status = Status(kind: .info, text: "Lendo laudo \(i + 1)/\(files.count) com IA… (alguns segundos)")
                let model = self.model
                let req = await Task.detached(priority: .userInitiated) { UploadPrep.prepare(file, model: model) }.value
                let text = try await AIReader.read(req, apiKey: key)
                merged.merge(try BiometryReport.parse(text))
            }
            calc.apply(merged)
            let warn = merged.warnings()
            status = Status(kind: warn.isEmpty ? .ok : .error,
                            text: "Laudo lido. Confira os valores antes de calcular.",
                            details: warn.isEmpty ? [] : ["⚠ Valores suspeitos, confira: " + warn.joined(separator: "; ")])
        } catch {
            status = Status(kind: .error, text: "Erro: \(error.localizedDescription)",
                            details: ["Você pode digitar os valores manualmente enquanto isso."])
        }
    }
}

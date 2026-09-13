import Foundation
import Observation
import IOLCore
import CoreTransferable
import UniformTypeIdentifiers

/// Estado completo de um planejamento, como salvo em disco.
struct CaseSnapshot: Codable, Equatable {
    var patientName: String
    var od: EyeForm
    var oe: EyeForm
    var odToric: ToricForm
    var oeToric: ToricForm
    var method: BiometryMethod
    var astigmatismOn: Bool
    var showMonocular: Bool
    var simulationNight: Bool
    var simulationHaloMode: Int
    var compareEye: Eye
    var compareA: String
    var compareB: String
}

/// Um caso salvo: nome, datas, resumo por olho (para a lista) e o estado.
struct SavedCase: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var summaryOD: String?
    var summaryOE: String?
    var snapshot: CaseSnapshot

    /// Nome de lista: paciente ou "Caso sem nome".
    static func defaultName(for snapshot: CaseSnapshot) -> String {
        let n = snapshot.patientName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Caso sem nome" : n
    }

    /// Nome de arquivo seguro: "Caso-Maria-da-Silva.iolcase.json".
    var fileName: String {
        let safe = name.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        return "Caso-" + (safe.isEmpty ? "sem-nome" : safe) + ".iolcase.json"
    }
}

/// Arquivo de casos (um ou vários) para compartilhar entre aparelhos (AirDrop, Arquivos, e-mail).
struct CaseFile: Codable {
    var format = "iolcase"
    var version = 1
    var cases: [SavedCase]

    init(cases: [SavedCase]) { self.cases = cases }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Aceita o arquivo do app ou um `SavedCase` avulso.
    static func parse(_ data: Data) throws -> [SavedCase] {
        if let file = try? decoder.decode(CaseFile.self, from: data) { return file.cases }
        if let one = try? decoder.decode(SavedCase.self, from: data) { return [one] }
        return try decoder.decode([SavedCase].self, from: data)
    }
}

/// Exportação sob demanda: o arquivo só é escrito quando o usuário compartilha.
struct CaseExport: Transferable {
    let cases: [SavedCase]
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { export in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(export.fileName)
            try CaseFile.encoder.encode(CaseFile(cases: export.cases)).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

/// Casos salvos em `Application Support/IOLCalc/cases.json` (dentro do container do app).
/// Lista em memória, gravada inteira a cada mudança (poucas dezenas de casos, arquivo pequeno).
@Observable
final class CaseStore {
    private(set) var cases: [SavedCase] = []
    private(set) var loadError: String?
    let fileURL: URL

    static let defaultURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("IOLCalc", isDirectory: true).appendingPathComponent("cases.json")
    }()

    init(fileURL: URL = CaseStore.defaultURL) {
        self.fileURL = fileURL
        load()
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { cases = []; return }
        do {
            cases = try Self.decoder.decode([SavedCase].self, from: data).sorted { $0.updatedAt > $1.updatedAt }
            loadError = nil
        } catch {
            cases = []
            loadError = "Não foi possível ler os casos salvos: \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(cases).write(to: fileURL, options: .atomic)
        } catch {
            loadError = "Não foi possível gravar os casos: \(error.localizedDescription)"
        }
    }

    /// Salva o estado do modelo como caso novo e devolve o caso.
    @discardableResult
    func saveNew(from model: CalculatorModel) -> SavedCase {
        let snap = model.snapshot()
        let now = Date()
        let c = SavedCase(id: UUID(), name: SavedCase.defaultName(for: snap), createdAt: now, updatedAt: now,
                          summaryOD: model.summary(.od), summaryOE: model.summary(.oe), snapshot: snap)
        cases.insert(c, at: 0)
        persist()
        model.loadedCaseID = c.id
        return c
    }

    /// Atualiza o caso de onde o modelo veio (ou salva um novo se ele não existe mais).
    @discardableResult
    func update(from model: CalculatorModel) -> SavedCase {
        guard let id = model.loadedCaseID, let i = cases.firstIndex(where: { $0.id == id }) else { return saveNew(from: model) }
        var c = cases[i]
        c.snapshot = model.snapshot()
        c.name = SavedCase.defaultName(for: c.snapshot)
        c.updatedAt = Date()
        c.summaryOD = model.summary(.od)
        c.summaryOE = model.summary(.oe)
        cases.remove(at: i)
        cases.insert(c, at: 0)
        persist()
        return c
    }

    func open(_ c: SavedCase, into model: CalculatorModel) {
        model.restore(c.snapshot, caseID: c.id)
    }

    func delete(_ c: SavedCase) {
        cases.removeAll { $0.id == c.id }
        persist()
    }

    func rename(_ c: SavedCase, to name: String) {
        guard let i = cases.firstIndex(where: { $0.id == c.id }) else { return }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        cases[i].name = n.isEmpty ? SavedCase.defaultName(for: cases[i].snapshot) : n
        persist()
    }

    func contains(_ id: UUID?) -> Bool { id.map { i in cases.contains { $0.id == i } } ?? false }

    func export(_ c: SavedCase) -> CaseExport { CaseExport(cases: [c], fileName: c.fileName) }

    func exportAll() -> CaseExport {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"
        return CaseExport(cases: cases, fileName: "Casos-LIO-\(f.string(from: Date())).iolcase.json")
    }

    /// Importa os casos de um arquivo. Casos com o mesmo id de um existente são atualizados se
    /// forem mais recentes; os demais entram como novos. Devolve quantos entraram/atualizaram.
    @discardableResult
    func importCases(from url: URL) throws -> Int {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let incoming = try CaseFile.parse(try Data(contentsOf: url))
        var n = 0
        for c in incoming {
            if let i = cases.firstIndex(where: { $0.id == c.id }) {
                if c.updatedAt > cases[i].updatedAt { cases[i] = c; n += 1 }
            } else {
                cases.append(c); n += 1
            }
        }
        cases.sort { $0.updatedAt > $1.updatedAt }
        persist()
        return n
    }
}

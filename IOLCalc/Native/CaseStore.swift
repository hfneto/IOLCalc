import Foundation
import Observation
import IOLCore

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
}

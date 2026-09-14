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

/// Casos salvos em `Application Support/IOLCalc/cases.json` (dentro do container do app) e, quando o
/// iCloud está disponível, também em `iCloud Drive/IOLCalc/Documents/cases.json` — o mesmo arquivo
/// no Mac, no iPhone e no iPad. Lista em memória, gravada inteira a cada mudança (poucas dezenas de
/// casos, arquivo pequeno). O arquivo do iCloud é a verdade; o local é um espelho para abrir rápido
/// e para quando o iCloud não estiver disponível.
@Observable
final class CaseStore {
    private(set) var cases: [SavedCase] = []
    private(set) var loadError: String?
    /// Arquivo local (espelho).
    let fileURL: URL
    /// Arquivo no container do iCloud, quando ativo.
    private(set) var cloudURL: URL?
    /// Texto curto para a interface: "iCloud ativo", "iCloud indisponível…", nil enquanto verifica.
    private(set) var cloudStatus: String?
    var isCloud: Bool { cloudURL != nil }

    static let containerID = "iCloud.br.com.drhallim.IOLCalc"
    private static let migratedKey = "iol_cloud_migrated"
    @ObservationIgnored private var query: NSMetadataQuery?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var lastCloudWrite: Data?

    static let defaultURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("IOLCalc", isDirectory: true).appendingPathComponent("cases.json")
    }()

    /// `useCloud: false` nos testes de depuração (arquivo temporário, sem iCloud).
    init(fileURL: URL = CaseStore.defaultURL, useCloud: Bool = false) {
        self.fileURL = fileURL
        load()
        if useCloud { attachCloud() }
    }

    deinit {
        query?.stop()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
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
            let data = try Self.encoder.encode(cases)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            if let cloudURL { try writeCloud(data, to: cloudURL) }
            loadError = nil
        } catch {
            loadError = "Não foi possível gravar os casos: \(error.localizedDescription)"
        }
    }

    // MARK: iCloud

    /// Descobre o container do iCloud (fora da thread principal: a primeira chamada pode demorar),
    /// funde o arquivo de lá com o local e passa a observar mudanças vindas dos outros aparelhos.
    private func attachCloud() {
        Task.detached(priority: .utility) { [weak self] in
            let container = FileManager.default.url(forUbiquityContainerIdentifier: CaseStore.containerID)
            guard let self else { return }
            await MainActor.run { self.cloudReady(container) }
        }
    }

    @MainActor private func cloudReady(_ container: URL?) {
        guard let container else {
            cloudStatus = "iCloud indisponível — entre no iCloud nos Ajustes e ative o iCloud Drive para sincronizar os casos"
            return
        }
        let docs = container.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        let url = docs.appendingPathComponent("cases.json")
        cloudURL = url
        cloudStatus = "iCloud ativo — os casos aparecem no Mac, no iPhone e no iPad"
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        reloadFromCloud()
        startQuery()
    }

    private func startQuery() {
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        q.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, "cases.json")
        for name in [NSNotification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: q, queue: .main) { [weak self] _ in
                self?.cloudChanged()
            })
        }
        query = q
        q.start()
    }

    private func cloudChanged() {
        guard let q = query, let url = cloudURL else { return }
        q.disableUpdates()
        defer { q.enableUpdates() }
        for case let item as NSMetadataItem in q.results {
            guard let itemURL = item.value(forAttribute: NSMetadataItemURLKey) as? URL, itemURL.standardizedFileURL == url.standardizedFileURL else { continue }
            let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
            if status == NSMetadataUbiquitousItemDownloadingStatusCurrent {
                reloadFromCloud()
            } else {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            }
        }
    }

    /// Lê o arquivo do iCloud (com coordenação) e aplica. Na primeira vez em cada aparelho, funde
    /// com os casos locais (o mais recente de cada id vence); depois, o iCloud manda — assim um caso
    /// apagado num aparelho some nos outros.
    private func reloadFromCloud() {
        guard let cloudURL else { return }
        var data: Data?
        var err: NSError?
        NSFileCoordinator().coordinate(readingItemAt: cloudURL, options: [], error: &err) { u in data = try? Data(contentsOf: u) }
        let remote: [SavedCase]
        if let data {
            if data == lastCloudWrite { return }   // eco da nossa própria gravação
            guard let parsed = try? Self.decoder.decode([SavedCase].self, from: data) else {
                loadError = "Arquivo de casos do iCloud ilegível; mantendo a cópia local."
                return
            }
            remote = parsed
        } else {
            remote = []   // ainda não existe no iCloud (ou não baixou): só publicar os locais
        }
        let migrated = UserDefaults.standard.bool(forKey: Self.migratedKey)
        var merged: [SavedCase]
        if migrated && data != nil {
            merged = remote
        } else {
            merged = remote
            for c in cases {
                if let i = merged.firstIndex(where: { $0.id == c.id }) {
                    if c.updatedAt > merged[i].updatedAt { merged[i] = c }
                } else {
                    merged.append(c)
                }
            }
        }
        merged.sort { $0.updatedAt > $1.updatedAt }
        let changed = merged != cases
        cases = merged
        if changed || data == nil || !migrated { persist() }
        if data != nil || !cases.isEmpty { UserDefaults.standard.set(true, forKey: Self.migratedKey) }
    }

    private func writeCloud(_ data: Data, to url: URL) throws {
        var err: NSError?
        var inner: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &err) { u in
            do { try data.write(to: u, options: .atomic) } catch { inner = error }
        }
        if let err { throw err }
        if let inner { throw inner }
        lastCloudWrite = data
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

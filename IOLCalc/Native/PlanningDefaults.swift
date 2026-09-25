import Foundation
import Observation
import IOLCore

/// Padrões do usuário para casos novos: SIA e eixo da incisão por olho (seção 7), quantidade de
/// miopia da monovisão e as lentes de referência do cenário alternativo (seção 5). Editável em
/// Configurações › Padrões. Guardado no UserDefaults e no iCloud (`NSUbiquitousKeyValueStore`,
/// chave `iol_planning_defaults`), como as lentes favoritas.
@Observable
final class PlanningDefaults {
    static let shared = PlanningDefaults()

    private static let key = "iol_planning_defaults"

    /// SIA (D) das incisões, texto com vírgula.
    var sia = "0,10" { didSet { save() } }
    /// Eixo da incisão (°) por olho: temporal = 180° no OD e 0° no OE.
    var incisionAxisOD = "180" { didSet { save() } }
    var incisionAxisOE = "0" { didSet { save() } }
    /// Miopia (D, positivo) deixada no olho não dominante na monovisão.
    var monovisionAmount = "1,25" { didSet { save() } }
    /// LIO monofocal do cenário "monovisão monofocal" (comparação da seção 5/6).
    var monovisionLensID = "clareon-mono" { didSet { save() } }
    /// LIO multifocal do cenário "multifocal bilateral".
    var multifocalLensID = "panoptix" { didSet { save() } }

    @ObservationIgnored private var loading = false
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        let kvs = NSUbiquitousKeyValueStore.default
        let saved = (kvs.dictionary(forKey: Self.key) as? [String: String]) ?? (defaults.dictionary(forKey: Self.key) as? [String: String])
        if let saved { apply(saved) }
        observer = NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                                          object: kvs, queue: .main) { [weak self] note in
            let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
            guard keys.contains(Self.key), let remote = kvs.dictionary(forKey: Self.key) as? [String: String] else { return }
            self?.apply(remote, fromCloud: true)
        }
        kvs.synchronize()
    }

    var dictionary: [String: String] {
        ["sia": sia, "incisionOD": incisionAxisOD, "incisionOE": incisionAxisOE,
         "monovision": monovisionAmount, "monoLens": monovisionLensID, "multiLens": multifocalLensID]
    }

    private func apply(_ d: [String: String], fromCloud: Bool = false) {
        loading = true
        defer { loading = false }
        if let v = d["sia"] { sia = v }
        if let v = d["incisionOD"] { incisionAxisOD = v }
        if let v = d["incisionOE"] { incisionAxisOE = v }
        if let v = d["monovision"] { monovisionAmount = v }
        if let v = d["monoLens"], LensCatalog.lens(id: v) != nil { monovisionLensID = v }
        if let v = d["multiLens"], LensCatalog.lens(id: v) != nil { multifocalLensID = v }
        if fromCloud { UserDefaults.standard.set(dictionary, forKey: Self.key) }
    }

    private func save() {
        guard !loading else { return }
        UserDefaults.standard.set(dictionary, forKey: Self.key)
        let kvs = NSUbiquitousKeyValueStore.default
        kvs.set(dictionary, forKey: Self.key)
        kvs.synchronize()
    }

    func restoreDefaults() {
        sia = "0,10"; incisionAxisOD = "180"; incisionAxisOE = "0"
        monovisionAmount = "1,25"; monovisionLensID = "clareon-mono"; multifocalLensID = "panoptix"
    }

    /// Valor numérico da monovisão (D, positivo), com limite de bom senso.
    var monovisionValue: Double { min(3, max(0, Num.parse(monovisionAmount) ?? 1.25)) }

    func incisionAxis(_ eye: Eye) -> String { eye == .od ? incisionAxisOD : incisionAxisOE }

    /// Miopia da monovisão de um texto do caso (ou o padrão se o texto não for número).
    func monovisionValueOr(_ text: String) -> Double { min(3, max(0, Num.parse(text) ?? monovisionValue)) }
}

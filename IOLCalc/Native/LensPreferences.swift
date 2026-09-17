import Foundation
import Observation
import IOLCore

/// LIOs favoritas: as que aparecem no seletor da seção 2 e no comparador. Começa com as 20 lentes
/// da versão original; editável em Configurações › Lentes. Guardado no UserDefaults e no iCloud
/// (`NSUbiquitousKeyValueStore`, chave `iol_fav_lenses`): marcar no Mac vale no iPhone e no iPad.
/// Exige o entitlement `com.apple.developer.ubiquity-kvstore-identifier` (iCloud › Key-value
/// storage); sem ele o iCloud é ignorado sem erro e as favoritas ficam só no aparelho.
@MainActor
@Observable
final class LensPreferences {
    static let shared = LensPreferences()

    private static let key = "iol_fav_lenses"

    /// Ids favoritos na ordem do catálogo.
    private(set) var favorites: [String] {
        didSet {
            UserDefaults.standard.set(favorites, forKey: Self.key)
            let kvs = NSUbiquitousKeyValueStore.default
            kvs.set(favorites, forKey: Self.key)
            kvs.synchronize()
        }
    }
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        let kvs = NSUbiquitousKeyValueStore.default
        // O iCloud manda quando já tem valor (outro aparelho marcou); senão, o local ou o padrão.
        let saved = (kvs.array(forKey: Self.key) as? [String]) ?? defaults.stringArray(forKey: Self.key)
        favorites = Self.ordered(saved ?? LensCatalog.defaultFavorites)
        observer = NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                                          object: kvs, queue: .main) { [weak self] note in
            let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
            guard keys.contains(Self.key) else { return }
            Task { @MainActor in self?.applyCloud() }
        }
        kvs.synchronize()
    }

    /// Mudança vinda de outro aparelho.
    private func applyCloud() {
        guard let remote = NSUbiquitousKeyValueStore.default.array(forKey: Self.key) as? [String] else { return }
        let ordered = Self.ordered(remote)
        if ordered != favorites {
            // grava só localmente (sem devolver ao iCloud o que veio de lá)
            UserDefaults.standard.set(ordered, forKey: Self.key)
            withMutation(keyPath: \.favorites) { _favorites = ordered }
        }
    }

    func isFavorite(_ id: String) -> Bool { favorites.contains(id) }

    func setFavorite(_ id: String, _ on: Bool) {
        guard LensCatalog.lens(id: id) != nil else { return }
        if on, !favorites.contains(id) { favorites = Self.ordered(favorites + [id]) }
        if !on { favorites.removeAll { $0 == id } }
    }

    func toggle(_ id: String) { setFavorite(id, !isFavorite(id)) }

    func restoreDefaults() { favorites = LensCatalog.defaultFavorites }

    /// Lentes favoritas como objetos, na ordem do catálogo.
    var favoriteLenses: [IOLLens] { favorites.compactMap { LensCatalog.lens(id: $0) } }

    /// Mantém a ordem do catálogo e descarta ids que não existem mais.
    private static func ordered(_ ids: [String]) -> [String] {
        let set = Set(ids)
        return LensCatalog.all.map(\.id).filter { set.contains($0) }
    }
}

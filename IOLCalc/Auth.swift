import Foundation
import Security

/// Chave da API da Anthropic, guardada no Keychain e sincronizada pelo iCloud Keychain.
/// Digitada uma vez (no Mac ou no iPhone), aparece nos outros aparelhos do mesmo Apple ID.
/// O app fala direto com `api.anthropic.com`; não há mais servidor intermediário.
enum APIKeyStore {
    private static let service = "br.com.drhallim.IOLCalc"
    private static let account = "anthropic-api-key"
    /// Item da versão anterior (login no WordPress). Apagado na primeira leitura.
    private static let legacyAccount = "credential"

    private static var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    static func load() -> String? {
        #if DEBUG
        // Capturas de depuração rodadas do terminal: o binário recém-compilado faria o Keychain pedir
        // confirmação e travaria a renderização.
        if UserDefaults.standard.bool(forKey: "iol_no_keychain") { return nil }
        #endif
        purgeLegacy()
        // Primeiro o item sincronizado; depois o item local da versão anterior (só deste aparelho),
        // que é promovido a sincronizado para chegar aos outros aparelhos.
        if let key = read(synchronizable: true) { return key }
        if let key = read(synchronizable: false) { save(key); return key }
        return nil
    }

    private static func read(synchronizable: Bool) -> String? {
        var q = base
        q[kSecAttrSynchronizable as String] = synchronizable
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        let key = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    static func save(_ key: String) {
        clear()
        var add = base
        add[kSecValueData as String] = Data(key.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        add[kSecAttrSynchronizable as String] = true
        // Itens sincronizados não podem ser "ThisDeviceOnly".
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        add[kSecAttrLabel as String] = "Calculadora de LIO — chave da API da Anthropic"
        SecItemAdd(add as CFDictionary, nil)
    }

    /// Apaga o item local e o sincronizado (em todos os aparelhos, via iCloud Keychain).
    static func clear() {
        var q = base
        q[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        SecItemDelete(q as CFDictionary)
    }

    /// Formato esperado de uma chave da Anthropic (`sk-ant-…`).
    static func looksLikeKey(_ s: String) -> Bool {
        let k = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return k.hasPrefix("sk-ant-") && k.count >= 40 && !k.contains(" ")
    }

    private static func purgeLegacy() {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: legacyAccount]
        SecItemDelete(q as CFDictionary)
    }
}

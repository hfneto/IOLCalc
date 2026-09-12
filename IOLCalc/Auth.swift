import Foundation
import Security

/// Chave da API da Anthropic, guardada no Keychain deste aparelho.
/// O app fala direto com `api.anthropic.com`; não há mais servidor intermediário.
enum APIKeyStore {
    private static let service = "br.com.drhallim.IOLCalc"
    private static let account = "anthropic-api-key"
    /// Item da versão anterior (login no WordPress). Apagado na primeira leitura.
    private static let legacyAccount = "credential"

    static func load() -> String? {
        purgeLegacy()
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        let key = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    static func save(_ key: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(key.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func clear() {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
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

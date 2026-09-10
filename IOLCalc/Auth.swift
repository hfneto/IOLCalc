import Foundation
import Security

/// Credencial guardada no Keychain. `token` vem do login no WordPress (plugin ≥ 2.2);
/// `password` é o modo legado (senha de acesso compartilhada do proxy).
struct Credential: Codable, Equatable {
    var email: String
    var token: String?
    var password: String?
    var name: String?

    /// Objeto injetado na página como `window.IOL_NATIVE.auth`.
    var pageJSON: [String: String] {
        var d = ["email": email]
        if let token { d["token"] = token } else if let password { d["password"] = password }
        return d
    }
}

enum CredentialStore {
    private static let service = "br.com.drhallim.IOLCalc"
    private static let account = "credential"

    static func load() -> Credential? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return try? JSONDecoder().decode(Credential.self, from: data)
    }

    static func save(_ c: Credential) {
        guard let data = try? JSONEncoder().encode(c) else { return }
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func clear() {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
    }
}

enum AuthError: LocalizedError {
    case server(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .server(let m): return m
        case .network(let m): return "Sem conexão com o servidor: \(m)"
        }
    }
}

enum AuthService {
    static let loginURL = URL(string: "https://drhallim.com.br/wp-json/iol/v1/login")!

    /// Tenta o login do plugin 2.2. Se o servidor ainda não tiver o endpoint (404),
    /// cai no modo legado: a senha digitada vira a senha de acesso compartilhada.
    static func login(email: String, password: String) async throws -> Credential {
        var req = URLRequest(url: loginURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["email": email, "password": password])
        req.timeoutInterval = 20
        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: req) }
        catch { throw AuthError.network(error.localizedDescription) }
        let http = resp as? HTTPURLResponse
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        switch http?.statusCode ?? 0 {
        case 200:
            guard let token = json?["token"] as? String else { throw AuthError.server("Resposta inesperada do servidor.") }
            return Credential(email: email, token: token, password: nil, name: json?["name"] as? String)
        case 404:
            // plugin antigo: sem endpoint de login
            return Credential(email: email, token: nil, password: password, name: nil)
        default:
            throw AuthError.server((json?["error"] as? String) ?? "Erro \(http?.statusCode ?? 0) no servidor.")
        }
    }
}

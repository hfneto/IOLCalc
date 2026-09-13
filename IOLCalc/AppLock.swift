import Foundation
import LocalAuthentication
import Observation

/// Bloqueio do app por Face ID / Touch ID (ou senha do aparelho). Vale quando existe uma chave da
/// API guardada: ao abrir o app, pede a biometria e libera o uso da chave; quem cancelar pode usar a
/// calculadora, mas a leitura por IA pede a biometria de novo antes de usar a chave.
/// O Keychain em si já é protegido pelo desbloqueio do aparelho; isto é uma trava de uso do app.
@Observable @MainActor
final class AppLock {
    static let shared = AppLock()

    /// A tela de bloqueio está cobrindo o app.
    var isLocked = false
    /// A biometria (ou senha) foi confirmada nesta sessão: a chave pode ser usada.
    private(set) var keyUnlocked = false
    var lastError: String?
    private var busy = false
    private var backgroundedAt: Date?

    private static let enabledKey = "iol_lock_enabled"
    /// Depois deste tempo em segundo plano o app pede a biometria de novo ao voltar.
    static let relockAfter: TimeInterval = 5 * 60

    /// Preferência "Pedir Face ID / Touch ID ao abrir o app" (ligada por padrão).
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Há o que proteger: trava ligada e chave guardada.
    static var shouldLock: Bool { isEnabled && APIKeyStore.load() != nil }

    /// Nome do método disponível neste aparelho, para os textos da tela.
    static var methodName: String {
        let ctx = LAContext()
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return "senha do aparelho" }
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "senha do aparelho"
        }
    }

    /// Ao abrir o app: mostra a tela de bloqueio e já pede a biometria.
    func lockAtLaunch() async {
        guard Self.shouldLock else { isLocked = false; keyUnlocked = true; return }
        isLocked = true
        _ = await unlock()
    }

    /// Chamado quando o app vai para segundo plano / volta (iOS e Mac).
    func noteBackground() { backgroundedAt = Date() }

    func noteForeground() async {
        guard let t = backgroundedAt else { return }
        backgroundedAt = nil
        guard Self.shouldLock, Date().timeIntervalSince(t) > Self.relockAfter else { return }
        keyUnlocked = false
        isLocked = true
        _ = await unlock()
    }

    /// A chave acabou de ser digitada e conferida: nesta sessão ela está liberada.
    func keyJustSaved() { keyUnlocked = true; isLocked = false }

    /// Antes de usar a chave: `true` se a biometria já foi confirmada ou acaba de ser.
    func ensureKeyAccess() async -> Bool {
        if keyUnlocked || !Self.isEnabled { return true }
        return await unlock()
    }

    /// Usar a calculadora sem liberar a chave (a leitura por IA pedirá a biometria depois).
    func skip() { isLocked = false }

    /// Pede Face ID / Touch ID / senha. Se o aparelho não tem nenhum método, libera direto.
    @discardableResult
    func unlock() async -> Bool {
        guard !busy else { return keyUnlocked }
        busy = true
        defer { busy = false }
        lastError = nil
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Agora não"
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            // Sem Face ID, Touch ID nem senha configurados: não há como travar.
            keyUnlocked = true; isLocked = false
            return true
        }
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication,
                                                  localizedReason: "Liberar a chave da API para a leitura de laudos")
            if ok { keyUnlocked = true; isLocked = false }
            return ok
        } catch let e as LAError {
            switch e.code {
            case .userCancel, .appCancel, .systemCancel: lastError = nil
            default: lastError = e.localizedDescription
            }
            return false
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}

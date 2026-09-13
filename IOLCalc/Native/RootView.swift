import SwiftUI

/// Raiz do app: a calculadora nativa, coberta pela tela de bloqueio (Face ID / Touch ID) enquanto a
/// chave da API não foi liberada. (A página web embutida foi removida na Fase 8.)
struct RootView: View {
    @State private var lock = AppLock.shared
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack {
            CompactWidthProvider { NativeCalculatorView() }
            if lock.isLocked {
                LockScreen(lock: lock).transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: lock.isLocked)
        .background(Theme.bg)
        // A paleta é clara e fixa (`Theme`). Sem isto, no modo escuro do sistema os controles nativos
        // (menus, caixas de seleção, setas) e o texto padrão saem brancos sobre os fundos claros —
        // o seletor de LIO "sumia" no macOS 26 em modo escuro.
        .preferredColorScheme(.light)
        .task { await lock.lockAtLaunch() }
        .onChange(of: phase) { _, new in
            switch new {
            case .background: lock.noteBackground()
            case .active: Task { await lock.noteForeground() }
            default: break
            }
        }
        #if os(macOS) && DEBUG
        .onAppear { DebugSnapshot.runIfRequested() }
        #endif
    }
}

/// Tela de bloqueio: pede a biometria de novo ou deixa entrar sem a leitura por IA.
struct LockScreen: View {
    @Bindable var lock: AppLock

    var body: some View {
        VStack(spacing: 18) {
            Image("AppIcon-Login").resizable().scaledToFit().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 16))
            Text("Calculadora de LIO").font(.title2.weight(.bold))
            Text("Confirme com \(AppLock.methodName) para liberar a chave da API guardada.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let err = lock.lastError {
                Text(err).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            Button {
                Task { await lock.unlock() }
            } label: {
                Label("Desbloquear", systemImage: lockIcon).frame(maxWidth: 240)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            Button("Usar sem leitura por IA") { lock.skip() }.font(.footnote)
        }
        .padding(28)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }

    private var lockIcon: String {
        switch AppLock.methodName {
        case "Face ID": return "faceid"
        case "Touch ID": return "touchid"
        case "Optic ID": return "opticid"
        default: return "lock.open"
        }
    }
}

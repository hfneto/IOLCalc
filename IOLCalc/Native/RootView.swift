import SwiftUI

/// Raiz do app durante a migração: alterna entre a página web embutida (completa) e a
/// versão nativa em SwiftUI (seções 1 a 3, por enquanto). Some quando a migração terminar.
struct RootView: View {
    @AppStorage("iol_native_ui") private var useNative = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $useNative) {
                    Text("Página web").tag(false)
                    Text("Nativo · beta").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 260)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Theme.card)
            Divider()
            if useNative {
                NativeCalculatorView()
            } else {
                ContentView()
            }
        }
        .background(Theme.bg)
        // A paleta é clara e fixa (`Theme`). Sem isto, no modo escuro do sistema os controles nativos
        // (menus, caixas de seleção, setas) e o texto padrão saem brancos sobre os fundos claros —
        // o seletor de LIO "sumia" no macOS 26 em modo escuro.
        .preferredColorScheme(.light)
        #if os(macOS) && DEBUG
        .onAppear { DebugSnapshot.runIfRequested() }
        #endif
    }
}

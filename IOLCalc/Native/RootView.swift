import SwiftUI

/// Raiz do app: a calculadora nativa. (A página web embutida foi removida na Fase 8.)
struct RootView: View {
    var body: some View {
        CompactWidthProvider { NativeCalculatorView() }
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

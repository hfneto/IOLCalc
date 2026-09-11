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
        #if os(macOS) && DEBUG
        .onAppear { DebugSnapshot.runIfRequested() }
        #endif
    }
}

import SwiftUI

/// Tela de configuração da chave da API da Anthropic (substitui o antigo login no WordPress).
struct APIKeyView: View {
    /// `true` quando já existe uma chave e o usuário só está trocando.
    var isChanging: Bool
    var onSave: (String) -> Void
    var onSkip: () -> Void

    @State private var key = ""
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focused: Bool

    private static let consoleURL = URL(string: "https://console.anthropic.com/settings/keys")!

    var body: some View {
        VStack(spacing: 18) {
            Image("AppIcon-Login").resizable().scaledToFit().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(spacing: 6) {
                Text("Calculadora de LIO").font(.title2.weight(.bold))
                Text("Cole a sua chave da API da Anthropic para ativar a leitura de laudos por IA. A chave fica guardada no Keychain deste aparelho e os laudos vão direto para a API, sem passar por nenhum servidor intermediário.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Chave da API").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                SecureField("sk-ant-…", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    #if os(iOS)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    #endif
                    .onSubmit { submit() }
                Button("Criar ou copiar uma chave em console.anthropic.com") {
                    ExternalLinks.open(Self.consoleURL)
                }
                .font(.footnote).buttonStyle(.plain).foregroundStyle(.tint)
            }
            if let error {
                Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            Button(action: submit) {
                HStack {
                    if busy { ProgressView().controlSize(.small) }
                    Text(busy ? "Verificando…" : "Salvar chave").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(busy || !APIKeyStore.looksLikeKey(key))
            Button(isChanging ? "Cancelar" : "Usar sem leitura por IA", action: onSkip).font(.footnote)
        }
        .padding(28)
        .frame(maxWidth: 420)
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
        #endif
        .onAppear { focused = true }
    }

    private func submit() {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busy, APIKeyStore.looksLikeKey(k) else { return }
        busy = true; error = nil
        Task {
            do {
                try await AIReader.validate(apiKey: k)
                APIKeyStore.save(k)
                onSave(k)
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}

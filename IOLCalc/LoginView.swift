import SwiftUI

struct LoginView: View {
    var onLogin: (Credential) -> Void
    var onSkip: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focus: Field?
    enum Field { case email, password }

    var body: some View {
        VStack(spacing: 18) {
            Image("AppIcon-Login").resizable().scaledToFit().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(spacing: 6) {
                Text("Calculadora de LIO").font(.title2.weight(.bold))
                Text("Entre com a sua conta do site para ativar a leitura de laudos por IA. Você só faz isso uma vez.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("E-mail").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("nome@exemplo.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.username)
                        .focused($focus, equals: .email)
                        #if os(iOS)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        #endif
                        .onSubmit { focus = .password }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Senha").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    SecureField("senha", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .focused($focus, equals: .password)
                        .onSubmit { submit() }
                }
            }
            if let error {
                Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            Button(action: submit) {
                HStack {
                    if busy { ProgressView().controlSize(.small) }
                    Text(busy ? "Entrando…" : "Entrar").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(busy || email.isEmpty || password.isEmpty)
            Button("Usar sem leitura por IA", action: onSkip).font(.footnote)
        }
        .padding(28)
        .frame(maxWidth: 400)
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
        #endif
        .onAppear { focus = .email }
    }

    private func submit() {
        guard !busy, !email.isEmpty, !password.isEmpty else { return }
        busy = true; error = nil
        Task {
            do {
                let c = try await AuthService.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
                CredentialStore.save(c)
                onLogin(c)
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}

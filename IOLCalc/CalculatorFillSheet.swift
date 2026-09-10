import SwiftUI
import WebKit

/// Pedido da página para abrir uma calculadora externa já preenchida.
struct ExternalCalculator: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let dataJSON: String
    let fillSource: String
}

/// Abre a calculadora oficial dentro do app e injeta a biometria nos campos reconhecidos.
struct CalculatorFillSheet: View {
    let calc: ExternalCalculator
    @Environment(\.dismiss) private var dismiss
    @State private var status = "carregando…"
    @State private var webView: WKWebView?

    var body: some View {
        NavigationStack {
            FillWebView(calc: calc, status: $status, webView: $webView)
                .navigationTitle(calc.name)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
                    ToolbarItemGroup(placement: .primaryAction) {
                        Text(status).font(.footnote).foregroundStyle(.secondary)
                        Button("Preencher de novo", systemImage: "arrow.clockwise") { fill() }
                        Button("Abrir no navegador", systemImage: "safari") { WebCoordinator.openExternally(calc.url) }
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 1000, idealWidth: 1100, minHeight: 720, idealHeight: 860)
        #endif
    }

    private func fill() {
        guard let webView else { return }
        FillWebView.Coordinator.fill(webView, calc: calc) { status = $0 }
    }
}

struct FillWebView: PlatformViewRepresentable {
    let calc: ExternalCalculator
    @Binding var status: String
    @Binding var webView: WKWebView?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private func build(_ context: Context) -> WKWebView {
        let wv = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        wv.navigationDelegate = context.coordinator
        #if DEBUG
        wv.isInspectable = true
        #endif
        wv.load(URLRequest(url: calc.url))
        DispatchQueue.main.async { webView = wv }
        return wv
    }

    #if os(iOS)
    func makeUIView(context: Context) -> WKWebView { build(context) }
    func updateUIView(_ view: WKWebView, context: Context) {}
    #else
    func makeNSView(context: Context) -> WKWebView { build(context) }
    func updateNSView(_ view: WKWebView, context: Context) {}
    #endif

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: FillWebView
        init(_ parent: FillWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let calc = parent.calc
            let setStatus = { [parent] (s: String) in parent.status = s }
            // muitas calculadoras montam o formulário depois do load: tenta 3 vezes
            for delay in [0.8, 2.5, 5.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    Self.fill(webView, calc: calc, status: setStatus)
                }
            }
        }

        static func fill(_ webView: WKWebView, calc: ExternalCalculator, status: @escaping (String) -> Void) {
            let js = "(\(calc.fillSource))(\(calc.dataJSON))"
            webView.evaluateJavaScript(js) { result, error in
                if let n = result as? Int, n > 0 { status("\(n) campo\(n == 1 ? "" : "s") preenchido\(n == 1 ? "" : "s") — confira") }
                else if error != nil { status("não foi possível preencher") }
                else { status("nenhum campo reconhecido — preencha à mão") }
            }
        }
    }
}

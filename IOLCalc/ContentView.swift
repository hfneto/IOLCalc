import SwiftUI
import WebKit

struct ContentView: View {
    @State private var credential: Credential? = CredentialStore.load()
    @State private var skippedLogin = false
    @State private var report: ReportDocument?
    @State private var externalCalc: ExternalCalculator?

    private var needsLogin: Bool { credential == nil && !skippedLogin }

    var body: some View {
        Group {
            if needsLogin {
                LoginView(onLogin: { credential = $0 }, onSkip: { skippedLogin = true })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.945, green: 0.961, blue: 0.976))
            } else {
                CalculatorWebView(nativeState: NativeState(credential: credential),
                                  onPopup: { report = ReportDocument(webView: $0) },
                                  onOpenCalculator: { externalCalc = $0 },
                                  onLogout: { CredentialStore.clear(); credential = nil; skippedLogin = false })
                #if os(iOS)
                .ignoresSafeArea(edges: .bottom)
                #endif
            }
        }
        .sheet(item: $report) { ReportSheet(document: $0) }
        .sheet(item: $externalCalc) { CalculatorFillSheet(calc: $0) }
    }
}

/// Uma janela aberta pela página (o relatório é escrito via `document.write` em um
/// `WKWebView` filho, que é apresentado em uma sheet).
struct ReportDocument: Identifiable {
    let id = UUID()
    let webView: WKWebView
}

/// O que o app injeta na página como `window.IOL_NATIVE`.
struct NativeState: Equatable {
    var credential: Credential?

    var script: String {
        var obj: [String: Any] = ["platform": platform]
        if let credential { obj["auth"] = credential.pageJSON } else { obj["auth"] = NSNull() }
        let data = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data("{}".utf8)
        return "window.IOL_NATIVE=\(String(decoding: data, as: UTF8.self));"
    }

    private var platform: String {
        #if os(iOS)
        return "ios"
        #else
        return "mac"
        #endif
    }
}

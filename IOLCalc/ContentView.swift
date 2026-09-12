import SwiftUI
import WebKit

struct ContentView: View {
    @State private var hasAIKey = APIKeyStore.load() != nil
    @State private var skippedSetup = false
    @State private var changingKey = false
    @State private var report: ReportDocument?
    @State private var externalCalc: ExternalCalculator?

    private var showSetup: Bool { changingKey || (!hasAIKey && !skippedSetup) }

    var body: some View {
        Group {
            if showSetup {
                APIKeyView(isChanging: hasAIKey,
                           onSave: { _ in hasAIKey = true; changingKey = false },
                           onSkip: { skippedSetup = true; changingKey = false })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.945, green: 0.961, blue: 0.976))
            } else {
                CalculatorWebView(nativeState: NativeState(hasAIKey: hasAIKey),
                                  onPopup: { report = ReportDocument(webView: $0) },
                                  onOpenCalculator: { externalCalc = $0 },
                                  onChangeKey: { changingKey = true },
                                  aiRead: { req in
                                      guard let key = APIKeyStore.load() else { throw AIReadError.noKey }
                                      return try await AIReader.read(req, apiKey: key)
                                  })
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
    /// Há uma chave da API salva; a página pode chamar `webkit.messageHandlers.aiRead`.
    var hasAIKey: Bool

    var script: String {
        let obj: [String: Any] = ["platform": platform, "ai": hasAIKey]
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

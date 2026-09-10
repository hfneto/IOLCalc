import SwiftUI
import WebKit

struct ContentView: View {
    @State private var report: ReportDocument?

    var body: some View {
        CalculatorWebView { popup in
            report = ReportDocument(webView: popup)
        }
        #if os(iOS)
        .ignoresSafeArea(edges: .bottom)
        #endif
        .sheet(item: $report) { doc in
            ReportSheet(document: doc)
        }
    }
}

/// Uma janela aberta pela página (o relatório é escrito via `document.write` em um
/// `WKWebView` filho, que é apresentado em uma sheet).
struct ReportDocument: Identifiable {
    let id = UUID()
    let webView: WKWebView
}

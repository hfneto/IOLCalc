import SwiftUI
import WebKit

/// Relatório gerado pela página (janela `window.open`), com impressão e exportação em PDF.
struct ReportSheet: View {
    let document: ReportDocument
    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL?
    @State private var pdfError: String?

    var body: some View {
        NavigationStack {
            ExistingWebView(webView: document.webView)
                .navigationTitle("Relatório")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fechar") { dismiss() }
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("Imprimir", systemImage: "printer") { printReport() }
                        if let pdfURL {
                            ShareLink(item: pdfURL) { Label("PDF", systemImage: "square.and.arrow.up") }
                        } else {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                .task { await exportPDF() }
        }
        #if os(macOS)
        .frame(minWidth: 820, idealWidth: 900, minHeight: 700, idealHeight: 860)
        #endif
    }

    /// O `document.write` do relatório é síncrono, mas o layout precisa de um ciclo para assentar.
    private func exportPDF() async {
        try? await Task.sleep(for: .milliseconds(600))
        let data: Data
        do {
            data = try await document.webView.pdf(configuration: WKPDFConfiguration())
        } catch {
            pdfError = error.localizedDescription
            return
        }
        let name = "Relatorio-LIO-\(Self.stamp()).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            pdfURL = url
        } catch {
            pdfError = error.localizedDescription
        }
    }

    private static func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: Date())
    }

    private func printReport() {
        #if os(iOS)
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = "Relatório de LIO"
        controller.printInfo = info
        controller.printFormatter = document.webView.viewPrintFormatter()
        controller.present(animated: true)
        #else
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        let operation = document.webView.printOperation(with: printInfo)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.view?.frame = NSRect(x: 0, y: 0, width: 800, height: 1100)
        if let window = document.webView.window {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
        #endif
    }
}

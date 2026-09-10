import SwiftUI
import WebKit

#if os(iOS)
import UIKit
typealias PlatformViewRepresentable = UIViewRepresentable
#else
import AppKit
typealias PlatformViewRepresentable = NSViewRepresentable
#endif

/// Origem com que a página embutida é carregada. Torna as chamadas relativas
/// (`/wp-json/iol/v1/read`) mesma origem, dispensando CORS, e dá ao `localStorage`
/// (senha da IA, método de cálculo) um domínio estável.
enum CalculatorPage {
    static let baseURL = URL(string: "https://drhallim.com.br/calculo/")!

    static func html() -> String {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html"),
              let html = try? String(contentsOf: url, encoding: .utf8) else {
            return "<h1>index.html não encontrado no bundle</h1>"
        }
        return html
    }
}

/// A calculadora (página web embutida) dentro de um `WKWebView`.
struct CalculatorWebView: PlatformViewRepresentable {
    let nativeState: NativeState
    /// Chamado quando a página abre uma janela vazia (relatório) e escreve nela.
    let onPopup: (WKWebView) -> Void
    let onOpenCalculator: (ExternalCalculator) -> Void
    let onLogout: () -> Void

    func makeCoordinator() -> WebCoordinator {
        WebCoordinator(onPopup: onPopup, onOpenCalculator: onOpenCalculator, onLogout: onLogout)
    }

    private func update(_ view: WKWebView, _ context: Context) {
        if context.coordinator.injectedState != nativeState {
            context.coordinator.inject(nativeState, into: view)
            view.loadHTMLString(CalculatorPage.html(), baseURL: CalculatorPage.baseURL)
        }
    }

    #if os(iOS)
    func makeUIView(context: Context) -> WKWebView { context.coordinator.makeWebView(state: nativeState) }
    func updateUIView(_ view: WKWebView, context: Context) { update(view, context) }
    #else
    func makeNSView(context: Context) -> WKWebView { context.coordinator.makeWebView(state: nativeState) }
    func updateNSView(_ view: WKWebView, context: Context) { update(view, context) }
    #endif
}

/// Exibe um `WKWebView` já existente (a janela do relatório).
struct ExistingWebView: PlatformViewRepresentable {
    let webView: WKWebView

    #if os(iOS)
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
    #else
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ view: WKWebView, context: Context) {}
    #endif
}

final class WebCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let onPopup: (WKWebView) -> Void
    let onOpenCalculator: (ExternalCalculator) -> Void
    let onLogout: () -> Void
    private(set) var injectedState: NativeState?

    init(onPopup: @escaping (WKWebView) -> Void, onOpenCalculator: @escaping (ExternalCalculator) -> Void, onLogout: @escaping () -> Void) {
        self.onPopup = onPopup
        self.onOpenCalculator = onOpenCalculator
        self.onLogout = onLogout
    }

    /// Reinstala o script `window.IOL_NATIVE` (roda antes da página, a cada carga).
    func inject(_ state: NativeState, into webView: WKWebView) {
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        ucc.addUserScript(WKUserScript(source: state.script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        injectedState = state
    }

    func makeWebView(state: NativeState) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.websiteDataStore = .default()
        #if os(iOS)
        config.allowsInlineMediaPlayback = true
        #endif
        config.userContentController.add(self, name: "openCalc")
        config.userContentController.add(self, name: "logout")

        let webView = WKWebView(frame: .zero, configuration: config)
        inject(state, into: webView)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        #if DEBUG
        webView.isInspectable = true
        #endif
        #if os(iOS)
        webView.scrollView.keyboardDismissMode = .interactive
        #endif
        webView.loadHTMLString(CalculatorPage.html(), baseURL: CalculatorPage.baseURL)
        return webView
    }

    // MARK: - Navegação: links externos abrem no navegador do sistema

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
        let isExternal = navigationAction.navigationType == .linkActivated
            && (url.scheme == "http" || url.scheme == "https")
            && url != CalculatorPage.baseURL
        if isExternal {
            Self.openExternally(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    // MARK: - window.open: relatório vira uma janela filha; links `_blank` vão para o navegador

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, !url.absoluteString.isEmpty, url.absoluteString != "about:blank" {
            Self.openExternally(url)
            return nil
        }
        let popup = WKWebView(frame: .zero, configuration: configuration)
        popup.uiDelegate = self
        #if DEBUG
        popup.isInspectable = true
        #endif
        onPopup(popup)
        return popup
    }

    // MARK: - Mensagens da página (window.webkit.messageHandlers.*)

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "logout":
            onLogout()
        case "openCalc":
            guard let body = message.body as? [String: Any],
                  let name = body["name"] as? String,
                  let urlString = body["url"] as? String, let url = URL(string: urlString),
                  let fill = body["fill"] as? String,
                  let data = body["data"], let json = try? JSONSerialization.data(withJSONObject: data) else { return }
            onOpenCalculator(ExternalCalculator(name: name, url: url, dataJSON: String(decoding: json, as: UTF8.self), fillSource: fill))
        default:
            break
        }
    }

    // MARK: - alert()/confirm(): o WKWebView descarta em silêncio sem isto

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        Self.presentAlert(message: message, from: webView, confirm: false) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        Self.presentAlert(message: message, from: webView, confirm: true, completion: completionHandler)
    }

    // MARK: - Helpers de plataforma

    static func openExternally(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    static func presentAlert(message: String, from webView: WKWebView, confirm: Bool, completion: @escaping (Bool) -> Void) {
        #if os(iOS)
        guard let presenter = webView.window?.rootViewController?.topMost else { completion(!confirm); return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        if confirm {
            alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in completion(false) })
        }
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completion(true) })
        presenter.present(alert, animated: true)
        #else
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        if confirm { alert.addButton(withTitle: "Cancelar") }
        if let window = webView.window {
            alert.beginSheetModal(for: window) { completion($0 == .alertFirstButtonReturn) }
        } else {
            completion(alert.runModal() == .alertFirstButtonReturn)
        }
        #endif
    }
}

#if os(iOS)
private extension UIViewController {
    var topMost: UIViewController {
        presentedViewController?.topMost ?? self
    }
}
#endif

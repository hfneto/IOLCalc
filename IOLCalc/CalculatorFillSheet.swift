import SwiftUI
import WebKit
#if os(iOS)
import UIKit
typealias PlatformViewRepresentable = UIViewRepresentable
#else
import AppKit
typealias PlatformViewRepresentable = NSViewRepresentable
#endif

enum ExternalLinks {
    static func open(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
}

/// As calculadoras oficiais (sites de terceiros) que o app abre numa sheet e tenta preencher.
struct OfficialCalculator: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL

    static let all: [OfficialCalculator] = [
        OfficialCalculator(id: "barrett", name: "Barrett Universal II", url: URL(string: "https://calc.apacrs.org/barrett_universal2105/")!),
        OfficialCalculator(id: "kane", name: "Kane", url: URL(string: "https://www.iolformula.com/")!),
        OfficialCalculator(id: "escrs", name: "ESCRS (EVO · Barrett · Kane · Hoffer QST)", url: URL(string: "https://iolcalculator.escrs.org/")!),
        OfficialCalculator(id: "rbf", name: "Hill-RBF", url: URL(string: "https://rbfcalculator.com/")!),
        OfficialCalculator(id: "lucena", name: "Lucena", url: URL(string: "https://formula.escolacearenseoftalmologia.com.br/")!),
    ]
}

/// Pedido para abrir uma calculadora externa já preenchida com a biometria.
struct ExternalCalculator: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    /// `{v:1, OD:{AL,K1,K2,ACD,LT,WTW,CCT,TK1,TK2,A,TGT}, OE:{…}}`, com `null` nos campos vazios.
    let dataJSON: String
    let fillSource: String

    init(_ calc: OfficialCalculator, dataJSON: String) {
        name = calc.name
        url = calc.url
        self.dataJSON = dataJSON
        fillSource = CalculatorFill.script
    }
}

enum CalculatorFill {
    /// Heurística de preenchimento por rótulos (a mesma do antigo bookmarklet "IOL ⇒ preencher"):
    /// para cada campo visível, descobre o rótulo (label, célula da tabela, placeholder, nome),
    /// o olho (OD/OE pelo texto, pelo contêiner ou pela metade da tela) e a grandeza; preenche os
    /// campos vazios e dispara `input`/`change`. Devolve quantos campos preencheu.
    static let script = #"""
    function iolFillPage(data){
      var map=[[/axial|(^|\b)al(\b|\s)/i,'AL'],[/k1|flat\s*k/i,'K1'],[/k2|steep\s*k/i,'K2'],
        [/\bacd\b|anterior\s*chamber/i,'ACD'],[/\blt\b|lens\s*thick/i,'LT'],[/wtw|white|\bcd\b|corneal\s*diam/i,'WTW'],
        [/a\s*-?\s*const/i,'A'],[/target|alvo|refraction|refra/i,'TGT']];
      var inputs=Array.prototype.slice.call(document.querySelectorAll('input[type=text],input[type=number],input:not([type])'));
      var filled=0;
      inputs.forEach(function(inp){
        if(inp.offsetParent===null)return;
        var lab='';
        if(inp.id){var l=document.querySelector('label[for="'+inp.id+'"]');if(l)lab=l.textContent;}
        if(!lab&&inp.closest('td')){var tr=inp.closest('tr');if(tr)lab=tr.cells[0]?tr.cells[0].textContent:'';}
        if(!lab)lab=(inp.getAttribute('placeholder')||'')+' '+(inp.getAttribute('aria-label')||'')+' '+inp.name+' '+inp.id;
        if(!lab.trim()&&inp.parentElement)lab=inp.parentElement.textContent.slice(0,60);
        var eye=/\bod\b|\(r\)|right|direito/i.test(lab)?'OD':(/\bos\b|\boe\b|\(l\)|left|esquerdo/i.test(lab)?'OE':null);
        if(!eye){var box=inp.closest('div,td,fieldset,section');for(var n=0;n<6&&box;n++){var t=(box.id+' '+box.className);if(/\bod\b|right/i.test(t)){eye='OD';break}if(/\bos\b|\boe\b|left/i.test(t)){eye='OE';break}box=box.parentElement;}}
        if(!eye){var r=inp.getBoundingClientRect();eye=r.left<window.innerWidth/2?'OD':'OE';}
        for(var i=0;i<map.length;i++){
          if(map[i][0].test(lab)){
            var k=map[i][1];
            var v=data[eye]&&data[eye][k];
            var empty=inp.value===''||(k==='TGT'&&/^-?0*\.?0*$/.test(inp.value));
            if(v!=null&&empty){
              inp.value=v;
              inp.dispatchEvent(new Event('input',{bubbles:true}));
              inp.dispatchEvent(new Event('change',{bubbles:true}));
              filled++;
            }
            break;
          }
        }
      });
      return filled;
    }
    """#
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
                        Button("Abrir no navegador", systemImage: "safari") { ExternalLinks.open(calc.url) }
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

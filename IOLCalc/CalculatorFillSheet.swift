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
    /// `{v:2, NAME, OD:{AL,K1,K2,K1_axis,K2_axis,ACD,LT,WTW,CCT,TK1,TK2,TK1_axis,TK2_axis,A,TGT}, OE:{…}}`, com `null` nos campos vazios.
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
    /// para cada campo, descobre o rótulo (label, célula da tabela, placeholder, aria-label, name,
    /// id), o olho (OD/OE pelo texto, pelo contêiner ou pela metade da tela) e a grandeza; preenche
    /// os campos vazios e dispara `input`/`change`. Devolve quantos campos preencheu.
    ///
    /// Campos escondidos (aba tórica da Kane, por exemplo) só são preenchidos quando o olho vem
    /// explícito do rótulo/contêiner — nunca pela posição na tela. As regras de eixo, TK e CCT vêm
    /// antes das de K para "k1_right_t_axis" não cair em K1.
    static let script = #"""
    function iolFillPage(data){
      var map=[
        [/tk1.*axis|axis.*tk1|total.*k1.*axis/i,'TK1_axis'],
        [/tk2.*axis|axis.*tk2|total.*k2.*axis/i,'TK2_axis'],
        [/k1.*axis|axis.*k1|flat.*axis|axis.*flat|k1_?ax|meridian.*1/i,'K1_axis'],
        [/k2.*axis|axis.*k2|steep.*axis|axis.*steep|k2_?ax|meridian.*2/i,'K2_axis'],
        [/\btk1\b|total\s*k1|tk\s*flat/i,'TK1'],
        [/\btk2\b|total\s*k2|tk\s*steep/i,'TK2'],
        [/\bcct\b|pachy|central\s*corneal|espessura\s*corn/i,'CCT'],
        [/axial|(^|\b)al(\b|\s|_)/i,'AL'],
        [/k1|flat\s*k|\bkf\b/i,'K1'],
        [/k2|steep\s*k|\bks\b/i,'K2'],
        [/\bacd\b|anterior\s*chamber/i,'ACD'],
        [/\blt\b|lens\s*thick/i,'LT'],
        [/wtw|white|\bcd\b|corneal\s*diam/i,'WTW'],
        [/a\s*-?\s*const/i,'A'],
        [/target|alvo|refraction|refra/i,'TGT'],
        [/patient|paciente|\bname\b|\bnome\b/i,'NAME']];
      var perEye={AL:1,K1:1,K2:1,ACD:1,LT:1,WTW:1,CCT:1,TK1:1,TK2:1,A:1,TGT:1,K1_axis:1,K2_axis:1,TK1_axis:1,TK2_axis:1};
      var zeroOK={TGT:1,K1_axis:1,K2_axis:1,TK1_axis:1,TK2_axis:1};
      var inputs=Array.prototype.slice.call(document.querySelectorAll('input[type=text],input[type=number],input[type=tel],input:not([type])'));
      var filled=0,lastKey=null;
      inputs.forEach(function(inp){
        if(inp.disabled||inp.readOnly)return;
        if(inp.dataset&&inp.dataset.iolFilled)return; // já preenchido numa passagem anterior (se o site limpou, respeita)
        var visible=inp.offsetParent!==null;
        var lab='';
        if(inp.id){var l=document.querySelector('label[for="'+inp.id+'"]');if(l)lab=l.textContent;}
        if(!lab&&inp.closest('td')){var c=inp.closest('td').previousElementSibling;while(c&&!c.textContent.trim())c=c.previousElementSibling;if(c)lab=c.textContent;}
        // <label> sem "for" num contêiner próximo que só tem este campo (Lucena, formulários Vue/React)
        if(!lab.trim()){var a=inp.parentElement;for(var d=0;d<4&&a;d++){if(a.querySelectorAll('input').length>1)break;var l2=a.querySelector('label,legend');if(l2&&l2.textContent.trim()){lab=l2.textContent;break;}a=a.parentElement;}}
        lab=(lab||'')+' '+(inp.getAttribute('placeholder')||'')+' '+(inp.getAttribute('aria-label')||'')+' '+(inp.name||'')+' '+(inp.id||'');
        if(!lab.trim()&&inp.parentElement)lab=inp.parentElement.textContent.slice(0,60);
        lab=lab.replace(/[_\-]+/g,' ').trim(); // "k1_right_t_axis" → "k1 right t axis" (\b não separa "_")
        if(/surgeon|doctor|cirurgi|medic|clinic|patient\s*(no|number|id)\b|\bid\b|record|prontu|first\s*name|primeiro\s*nome/i.test(lab))return;
        var eye=/\bod\b|\(r\)|right|direito|\br\b/i.test(lab)?'OD':(/\bos\b|\boe\b|\(l\)|left|esquerdo|\bl\b/i.test(lab)?'OE':null);
        if(!eye){var box=inp.closest('div,td,fieldset,section,form');for(var n=0;n<10&&box;n++){var t=(box.id+' '+box.className).replace(/[_\-]+/g,' ');if(/\bod\b|right/i.test(t)){eye='OD';break}if(/\bos\b|\boe\b|left/i.test(t)){eye='OE';break}box=box.parentElement;}}
        if(!eye){if(/\s1$/.test(lab))eye='OD';else if(/\s2$/.test(lab))eye='OE';} // Kane: aconstant_1 / target_ref_2
        var explicit=!!eye;
        if(!eye){var r=inp.getBoundingClientRect();eye=r.left<window.innerWidth/2?'OD':'OE';}
        // "Axis"/"Eixo" sozinho logo depois de K1/K2 (Lucena): é o eixo daquele K
        if(/^\s*(axis|eixo)\s*(\(°\)|°)?\s*$/i.test(lab)&&lastKey&&/^T?K[12]$/.test(lastKey))lab=lastKey+' axis';
        var matched=null;
        for(var i=0;i<map.length;i++){
          if(map[i][0].test(lab)){
            var k=map[i][1];
            matched=k;
            if(perEye[k]&&!visible&&!explicit)break;
            var v=perEye[k]?(data[eye]&&data[eye][k]):data[k];
            var empty=inp.value===''||(zeroOK[k]&&/^-?0*\.?0*$/.test(inp.value));
            if(v!=null&&empty){
              inp.value=v;
              if(inp.dataset)inp.dataset.iolFilled='1';
              inp.dispatchEvent(new Event('input',{bubbles:true}));
              inp.dispatchEvent(new Event('change',{bubbles:true}));
              filled++;
            }
            break;
          }
        }
        lastKey=matched;
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

    /// Script injetado em TODOS os frames (a Hill-RBF monta o formulário num iframe de outra
    /// origem, fora do alcance do `evaluateJavaScript`) no fim do carregamento de cada documento.
    /// Repete a heurística a cada 1,5 s por ≈5 min: a Kane só monta o formulário depois de
    /// "I Agree", a ESCRS depois dos termos, a Lucena depois de escolher a fórmula, e a aba tórica
    /// aparece ao clicar. O preenchimento é idempotente (só campos vazios). Cada passagem que
    /// preenche algo avisa o app pelo `iolFill`.
    private var userScript: String {
        """
        (function(){
          if (window.__iolFill) return;
          var data = \(calc.dataJSON);
          var fill = \(calc.fillSource);
          function tick(){ try { var n = fill(data); if (n > 0 && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.iolFill) window.webkit.messageHandlers.iolFill.postMessage(n); return n; } catch (e) { return 0; } }
          window.__iolFill = tick;
          tick();
          var k = 0;
          var t = setInterval(function(){ k++; if (k > 200) { clearInterval(t); return; } tick(); }, 1500);
        })();
        """
    }

    private func build(_ context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(source: userScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        config.userContentController.add(context.coordinator, name: "iolFill")
        let wv = WKWebView(frame: .zero, configuration: config)
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
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) { view.configuration.userContentController.removeScriptMessageHandler(forName: "iolFill") }
    #else
    func makeNSView(context: Context) -> WKWebView { build(context) }
    func updateNSView(_ view: WKWebView, context: Context) {}
    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) { view.configuration.userContentController.removeScriptMessageHandler(forName: "iolFill") }
    #endif

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: FillWebView
        private var filledTotal = 0

        init(_ parent: FillWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if filledTotal == 0 { parent.status = "aguardando o formulário — aceite os termos ou abra a calculadora no site" }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "iolFill", let n = message.body as? Int, n > 0 else { return }
            filledTotal += n
            parent.status = "\(filledTotal) campo\(filledTotal == 1 ? "" : "s") preenchido\(filledTotal == 1 ? "" : "s") — confira"
        }

        /// "Preencher de novo" (botão): uma passagem imediata no frame principal, com mensagem própria.
        static func fill(_ webView: WKWebView, calc: ExternalCalculator, status: @escaping (String) -> Void) {
            let js = "window.__iolFill ? window.__iolFill() : (\(calc.fillSource))(\(calc.dataJSON))"
            webView.evaluateJavaScript(js) { result, error in
                if let n = result as? Int, n > 0 { status("\(n) campo\(n == 1 ? "" : "s") preenchido\(n == 1 ? "" : "s") agora — confira") }
                else if error != nil { status("não foi possível preencher") }
                else { status("nenhum campo vazio reconhecido — preencha à mão o que faltar") }
            }
        }
    }
}

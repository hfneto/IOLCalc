// Testa a heurística de preenchimento (`CalculatorFill.script`) numa calculadora oficial real, sem
// abrir o app: carrega a página num WKWebView sem janela, injeta a biometria de exemplo e lista os
// campos preenchidos (name/id → valor). Não envia nada: só preenche os campos.
//
//   swiftc -O Tools/filltest.swift -o /tmp/filltest && /tmp/filltest https://www.iolformula.com/ [segundos]
import Foundation
import WebKit

let args = CommandLine.arguments
guard args.count >= 2, let url = URL(string: args[1]) else {
    print("uso: filltest <url> [segundos de espera]"); exit(2)
}
let wait = args.count >= 3 ? Double(args[2]) ?? 6 : 6

// Extrai o script do fonte do app (entre #""" e """#).
let src = try! String(contentsOfFile: "IOLCalc/CalculatorFillSheet.swift", encoding: .utf8)
let open = src.range(of: "#\"\"\"\n")!.upperBound
let close = src.range(of: "\"\"\"#", range: open..<src.endIndex)!.lowerBound
var script = String(src[open..<close])
// DEBUG_FILL=1: instrumenta o script para listar rótulo → olho → grandeza de cada campo.
if ProcessInfo.processInfo.environment["DEBUG_FILL"] != nil {
    script = script.replacingOccurrences(of: "var filled=0,lastKey=null;", with: "var filled=0,lastKey=null,dbg=[];")
        .replacingOccurrences(of: "if(inp.disabled||inp.readOnly)return;", with: "if(inp.disabled||inp.readOnly){dbg.push((inp.name||inp.id||'?')+' | (desabilitado/readonly) type='+inp.type);return;}")
        .replacingOccurrences(of: "record|prontu/i.test(lab))return;", with: "record|prontu/i.test(lab)){dbg.push((inp.name||inp.id||'?')+' | (excluído) '+lab.slice(0,40));return;}")
        .replacingOccurrences(of: "        lastKey=matched;", with: "        dbg.push((inp.name||inp.id||'?')+' | '+lab.slice(0,40)+' | '+eye+(explicit?'!':'')+' | '+matched+' | vis='+visible);\n        lastKey=matched;")
        .replacingOccurrences(of: "      return filled;", with: "      return filled+' n='+inputs.length+'\\n'+dbg.join('\\n');")
}

let data = """
{"v":2,"NAME":"Maria da Silva","OD":{"AL":23.62,"K1":43.25,"K2":44.10,"K1_axis":2,"K2_axis":92,"ACD":3.21,"LT":4.52,"WTW":11.8,"CCT":541,"TK1":43.30,"TK2":44.15,"TK1_axis":2,"TK2_axis":92,"A":119.1,"TGT":0},
 "OE":{"AL":23.70,"K1":43.40,"K2":44.05,"K1_axis":178,"K2_axis":88,"ACD":3.18,"LT":4.49,"WTW":11.9,"CCT":538,"TK1":null,"TK2":null,"TK1_axis":null,"TK2_axis":null,"A":119.1,"TGT":-0.25}}
"""

final class Delegate: NSObject, WKNavigationDelegate {
    var ran = false
    var pending = 0
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // PRE_JS: um trecho executado antes do preenchimento (ex.: aceitar os termos da Kane:
        // PRE_JS="document.querySelector('.btn_agreement').click()"). A página pode recarregar; o
        // preenchimento roda só uma vez, `wait` segundos depois da última navegação concluída.
        if !ran, let pre = ProcessInfo.processInfo.environment["PRE_JS"] {
            ran = true
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { webView.evaluateJavaScript(pre) { _, e in print("pré: \(e.map { "\($0)" } ?? "ok")") } }
        }
        pending += 1
        let me = pending
        let total = ProcessInfo.processInfo.environment["PRE_JS"] == nil ? wait : wait * 2
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            guard me == self.pending else { return }
            let js = "(\(script))(\(data))"
            webView.evaluateJavaScript(js) { result, error in
                print("preenchidos: \(result ?? "nil") erro: \(error.map { "\($0)" } ?? "-")")
                let dump = """
                'inputs='+document.querySelectorAll('input').length+' iframes='+document.querySelectorAll('iframe').length+'\\n'+Array.prototype.slice.call(document.querySelectorAll('input')).filter(function(i){return i.type!=='hidden'}).map(function(i){var lab='';if(i.id){var l=document.querySelector('label[for=\"'+i.id+'\"]');if(l)lab=l.textContent.trim();}if(!lab&&i.closest('td')){var tr=i.closest('tr');if(tr&&tr.cells[0])lab=tr.cells[0].textContent.trim();}return (i.name||i.id||'?')+' = '+i.value+(i.offsetParent===null?' (oculto)':'')+(i.value===''?'   [rótulo: '+lab.slice(0,40)+' | ph: '+(i.placeholder||'')+']':'')}).join('\\n')
                """
                webView.evaluateJavaScript(dump) { r, _ in
                    print(r as? String ?? "(sem campos)")
                    // DUMP=1: texto da página e botões/links (para descobrir a tela inicial dos SPAs)
                    guard ProcessInfo.processInfo.environment["DUMP"] != nil else { exit(0) }
                    // DUMP_JS=<arquivo>: executa esse JS em vez do padrão
                    if let f = ProcessInfo.processInfo.environment["DUMP_JS"], let js3 = try? String(contentsOfFile: f, encoding: .utf8) {
                        webView.evaluateJavaScript(js3) { r3, e3 in print(r3 as? String ?? "\(String(describing: e3))"); exit(0) }
                        return
                    }
                    let js2 = "document.body.innerText.slice(0,1200)+'\\n--- botões: '+Array.prototype.slice.call(document.querySelectorAll('button,a,[role=button]')).map(function(b){return '['+b.textContent.trim().slice(0,40)+']'}).join(' ')"
                    webView.evaluateJavaScript(js2) { r2, _ in print(r2 as? String ?? ""); exit(0) }
                }
            }
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { print("falha: \(error)"); exit(1) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { print("falha: \(error)"); exit(1) }
}

// USERSCRIPT=1: em vez de avaliar no frame principal, injeta o mesmo script de todos os frames
// que o app usa (com polling) e imprime cada aviso `iolFill` — serve para sites com iframe (RBF).
final class Handler: NSObject, WKScriptMessageHandler {
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        print("iolFill: \(m.body) (frame: \(m.frameInfo.request.url?.host ?? "?"), principal: \(m.frameInfo.isMainFrame))")
    }
}
let config = WKWebViewConfiguration()
if ProcessInfo.processInfo.environment["USERSCRIPT"] != nil {
    let user = """
    (function(){
      if (window.__iolFill) return;
      var data = \(data);
      var fill = \(script);
      function tick(){ try { var n = fill(data); if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.iolFill) window.webkit.messageHandlers.iolFill.postMessage(String(n)); return n; } catch (e) { window.webkit.messageHandlers.iolFill.postMessage('erro '+e); return 0; } }
      window.__iolFill = tick;
      tick();
      var k = 0;
      var t = setInterval(function(){ k++; if (k > 200) { clearInterval(t); return; } tick(); }, 1500);
    })();
    """
    config.userContentController.addUserScript(WKUserScript(source: user, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
    config.userContentController.add(Handler(), name: "iolFill")
}
let app = NSApplication.shared
let delegate = Delegate()
let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 1280, height: 900), configuration: config)
web.navigationDelegate = delegate
web.load(URLRequest(url: url))
DispatchQueue.main.asyncAfter(deadline: .now() + wait + 40) { print("tempo esgotado"); exit(1) }
app.run()

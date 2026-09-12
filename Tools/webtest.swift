import WebKit
import Foundation

// Carrega IOLCalc/index.html com um bridge aiRead falso e confere:
// 1) applyNativeState mostra o texto certo; 2) readBiometry usa o bridge e preenche os campos.
final class T: NSObject, WKNavigationDelegate, WKScriptMessageHandlerWithReply, WKScriptMessageHandler {
    var web: WKWebView!
    var done = false
    func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        let b = m.body as? [String: Any]
        print("bridge got model=\(b?["model"] ?? "-") is_pdf=\(b?["is_pdf"] ?? "-") media=\(b?["media_type"] ?? "-") dataLen=\((b?["data"] as? String)?.count ?? -1)")
        replyHandler(["text": "{\"name\":\"Teste\",\"OD\":{\"AL\":23.5,\"K1\":43.1,\"K2\":44.0,\"ACD\":3.1,\"LT\":4.2,\"WTW\":11.8,\"CCT\":540},\"OE\":{\"AL\":23.7,\"K1\":43.0,\"K2\":43.8,\"ACD\":3.2,\"LT\":4.3,\"WTW\":11.9,\"CCT\":545}}"], nil)
    }
    func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) { print("msg \(m.name)") }
    func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
        let js = """
        return (async()=>{
          const out={};
          out.acct=document.getElementById('acctInfo').textContent;
          out.btn=document.getElementById('logoutBtn').textContent+'|'+document.getElementById('logoutBtn').style.display;
          // arquivo falso (1x1 png) no input
          const png=atob('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
          const arr=new Uint8Array(png.length);for(let i=0;i<png.length;i++)arr[i]=png.charCodeAt(i);
          const f=new File([arr],'laudo.png',{type:'image/png'});
          const dt=new DataTransfer();dt.items.add(f);document.getElementById('bioFile').files=dt.files;
          await readBiometry();
          out.status=document.getElementById('bioStatus').textContent;
          out.OD_AL=document.getElementById('OD_AL').value; out.OE_CCT=document.getElementById('OE_CCT').value; out.name=(document.getElementById('patName')||{}).value;
          return JSON.stringify(out);
        })()
        """
        w.callAsyncJavaScript(js, arguments: [:], in: nil, in: .page) { r in
            switch r { case .success(let v): print("RESULT \(v ?? "nil")"); case .failure(let e): print("JSERR \(e)") }
            self.done = true
        }
    }
}
let t = T()
let cfg = WKWebViewConfiguration()
cfg.userContentController.addUserScript(WKUserScript(source: "window.IOL_NATIVE={platform:'mac',ai:true};", injectionTime: .atDocumentStart, forMainFrameOnly: true))
cfg.userContentController.addScriptMessageHandler(t, contentWorld: .page, name: "aiRead")
cfg.userContentController.add(t, name: "changeApiKey")
cfg.userContentController.add(t, name: "openCalc")
t.web = WKWebView(frame: CGRect(x: 0, y: 0, width: 1100, height: 900), configuration: cfg)
t.web.navigationDelegate = t
let html = try! String(contentsOfFile: "/Users/hfneto/Developer/IOLCalc/IOLCalc/index.html", encoding: .utf8)
t.web.loadHTMLString(html, baseURL: URL(string: "https://drhallim.com.br/calculo/")!)
let deadline = Date().addingTimeInterval(25)
while !t.done && Date() < deadline { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05)) }
if !t.done { print("TIMEOUT") }

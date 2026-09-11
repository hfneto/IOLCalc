import SwiftUI

#if os(macOS) && DEBUG
import AppKit

/// Depuração: `-iol_snapshot /caminho/arquivo.png` renderiza a janela principal em PNG
/// (sem precisar de permissão de gravação de tela) e encerra o app.
enum DebugSnapshot {
    static func runIfRequested() {
        guard let path = UserDefaults.standard.string(forKey: "iol_snapshot") else { return }
        let height = UserDefaults.standard.double(forKey: "iol_snapshot_height")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard let window = NSApp.windows.first(where: { $0.isVisible }) else { NSApp.terminate(nil); return }
            if height > 0 { window.setContentSize(NSSize(width: window.frame.width, height: height)) }
            if UserDefaults.standard.bool(forKey: "iol_snapshot_bottom"), let view = window.contentView,
               let scroll = firstScrollView(in: view), let doc = scroll.documentView {
                scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, doc.bounds.height - scroll.contentView.bounds.height)))
                scroll.reflectScrolledClipView(scroll.contentView)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                defer { NSApp.terminate(nil) }
                guard let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            }
        }
    }

    private static func firstScrollView(in view: NSView) -> NSScrollView? {
        if let s = view as? NSScrollView { return s }
        for sub in view.subviews { if let s = firstScrollView(in: sub) { return s } }
        return nil
    }
}
#endif

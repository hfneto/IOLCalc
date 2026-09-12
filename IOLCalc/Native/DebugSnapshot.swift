import SwiftUI

#if os(macOS) && DEBUG
import AppKit

/// Depuração: `-iol_snapshot /caminho/arquivo.png` renderiza a janela principal em PNG
/// (sem precisar de permissão de gravação de tela) e encerra o app.
enum DebugSnapshot {
    /// `-iol_chart_snapshot <png>`: renderiza só o gráfico de defocus do caso de exemplo com
    /// `ImageRenderer` (o `cacheDisplay` da janela não redesenha eixos/controles após rolagem).
    @MainActor static func renderChartIfRequested() {
        guard let path = UserDefaults.standard.string(forKey: "iol_chart_snapshot") else { return }
        let model = CalculatorModel()
        model.fillSample()
        let series = [
            DefocusSeries.sampled(id: "OD", color: Theme.od, width: 1.5, dashed: true) { model.monocularVA(.od, at: $0) },
            DefocusSeries.sampled(id: "OE", color: Theme.oe, width: 1.5, dashed: true) { model.monocularVA(.oe, at: $0) },
            DefocusSeries.sampled(id: "Binocular", color: Theme.bino, width: 3) { model.binocularVA(at: $0) },
        ].compactMap { $0 }
        let renderer = ImageRenderer(content: DefocusChart(series: series).frame(width: 900, height: 320).padding(16).background(Color.white))
        renderer.scale = 2
        if let img = renderer.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
    }

    @MainActor static func runIfRequested() {
        renderChartIfRequested()
        guard let path = UserDefaults.standard.string(forKey: "iol_snapshot") else { return }
        let height = UserDefaults.standard.double(forKey: "iol_snapshot_height")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard let window = NSApp.windows.first(where: { $0.isVisible }) else { NSApp.terminate(nil); return }
            if height > 0 { window.setContentSize(NSSize(width: window.frame.width, height: height)) }
            // `-iol_snapshot_bottom YES` rola até o fim; `-iol_snapshot_scroll <pt>` rola até a posição.
            let toBottom = UserDefaults.standard.bool(forKey: "iol_snapshot_bottom")
            let offset = UserDefaults.standard.double(forKey: "iol_snapshot_scroll")
            if toBottom || offset > 0, let view = window.contentView,
               let scroll = firstScrollView(in: view), let doc = scroll.documentView {
                let maxY = max(0, doc.bounds.height - scroll.contentView.bounds.height)
                scroll.contentView.scroll(to: NSPoint(x: 0, y: toBottom ? maxY : min(offset, maxY)))
                scroll.reflectScrolledClipView(scroll.contentView)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                defer { NSApp.terminate(nil) }
                guard let view = window.contentView else { return }
                view.layoutSubtreeIfNeeded()
                window.display()
                guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
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

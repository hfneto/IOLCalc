import SwiftUI

#if os(macOS) && DEBUG
import AppKit
import ImageIO
import UniformTypeIdentifiers

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

    /// `-iol_toric_snapshot <png>` e `-iol_sim_snapshot <png>`: renderizam as seções 7 e 6 do caso de
    /// exemplo com `ImageRenderer` (largura 1100). `-iol_sim_night YES` liga o modo noturno.
    @MainActor static func renderSectionsIfRequested() {
        let d = UserDefaults.standard
        func write(_ view: some View, to path: String) {
            let renderer = ImageRenderer(content: view.frame(width: 1100).padding(16).background(Theme.bg))
            renderer.scale = 2
            if let img = renderer.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            }
        }
        if let path = d.string(forKey: "iol_toric_snapshot") {
            let model = CalculatorModel()
            model.fillSample()
            write(ToricSection(model: model), to: path)
        }
        if let path = d.string(forKey: "iol_calcs_snapshot") {
            let model = CalculatorModel()
            model.fillSample()
            write(CalculatorsSection(model: model), to: path)
        }
        if let path = d.string(forKey: "iol_report_snapshot") {
            let model = CalculatorModel()
            model.fillSample()
            model.astigmatismOn = true
            let renderer = ImageRenderer(content: ReportView(model: model).frame(width: ReportPDF.pageSize.width - 2 * ReportPDF.margin))
            renderer.scale = 2
            if let img = renderer.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            }
        }
        if let path = d.string(forKey: "iol_report_pdf") {
            let model = CalculatorModel()
            model.fillSample()
            model.astigmatismOn = true
            try? ReportPDF.make(model: model).write(to: URL(fileURLWithPath: path))
        }
        if let path = d.string(forKey: "iol_sim_snapshot") {
            let model = CalculatorModel()
            model.fillSample()
            model.astigmatismOn = d.bool(forKey: "iol_sim_astig")
            write(SimulationSection(model: model), to: path)
        }
    }

    /// `-iol_prep_test <arquivo>`: roda `UploadPrep.prepare` no arquivo e grava `<arquivo>.txt` com
    /// tipo, tamanho do base64 e dimensões da imagem resultante.
    static func prepTestIfRequested() {
        guard let path = UserDefaults.standard.string(forKey: "iol_prep_test"), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }
        let file = PickedFile(data: data, name: (path as NSString).lastPathComponent, type: UTType(filenameExtension: (path as NSString).pathExtension))
        let t0 = Date()
        let req = UploadPrep.prepare(file, model: "x")
        var dims = "-"
        if !req.isPDF, let d = Data(base64Encoded: req.data), let src = CGImageSourceCreateWithData(d as CFData, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
            dims = "\(props[kCGImagePropertyPixelWidth] ?? "?")x\(props[kCGImagePropertyPixelHeight] ?? "?")"
        }
        let summary = "input=\(data.count)B isPDF=\(req.isPDF) media=\(req.mediaType) base64=\(req.data.count) dims=\(dims) time=\(Int(Date().timeIntervalSince(t0) * 1000))ms\n"
        try? summary.write(toFile: path + ".txt", atomically: true, encoding: .utf8)
    }

    /// `-iol_cases_test <arquivo.txt>`: salva, atualiza, recarrega de um JSON temporário, abre e apaga um
    /// caso; grava o resultado em texto ("OK" na última linha se tudo bateu).
    @MainActor static func casesTestIfRequested() {
        guard let out = UserDefaults.standard.string(forKey: "iol_cases_test") else { return }
        var log: [String] = []
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("iol-cases-test-\(UUID().uuidString).json")
        let store = CaseStore(fileURL: url)
        let model = CalculatorModel()
        model.fillSample()
        let saved = store.saveNew(from: model)
        log.append("saved id=\(saved.id) name=\(saved.name) od=\(saved.summaryOD ?? "-") oe=\(saved.summaryOE ?? "-")")
        model.selectLens("vivity", for: .oe)
        model[toric: .od].iolCylinder = "2,25"
        model.patientName = "Maria da Silva (rev.)"
        let updated = store.update(from: model)
        log.append("updated same=\(updated.id == saved.id) name=\(updated.name) oe=\(updated.summaryOE ?? "-") count=\(store.cases.count)")
        let store2 = CaseStore(fileURL: url)
        let fresh = CalculatorModel()
        var ok = store2.cases.count == 1
        if let c = store2.cases.first {
            store2.open(c, into: fresh)
            ok = ok && fresh.oe.lensID == "vivity" && fresh[toric: .od].iolCylinder == "2,25" && fresh.patientName == "Maria da Silva (rev.)"
                && fresh.od.al == "23,62" && fresh.loadedCaseID == c.id && fresh.snapshot() == model.snapshot()
            log.append("reloaded lens=\(fresh.oe.lensID) cyl=\(fresh[toric: .od].iolCylinder) snapshotEqual=\(fresh.snapshot() == model.snapshot())")
            store2.delete(c)
        }
        ok = ok && store2.cases.isEmpty && CaseStore(fileURL: url).cases.isEmpty
        log.append("deleted count=\(CaseStore(fileURL: url).cases.count) file=\(url.path)")
        log.append(ok ? "OK" : "FAIL")
        try? FileManager.default.removeItem(at: url)
        try? log.joined(separator: "\n").write(toFile: out, atomically: true, encoding: .utf8)
    }

    @MainActor static func runIfRequested() {
        prepTestIfRequested()
        casesTestIfRequested()
        renderChartIfRequested()
        renderSectionsIfRequested()
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
            // `-iol_popup_test <txt>`: lista os NSPopUpButton da janela, escolhe o 4º item do primeiro
            // (o seletor de LIO do OD) e dispara a ação, como um clique; a captura mostra o resultado.
            if let report = UserDefaults.standard.string(forKey: "iol_popup_test"), let view = window.contentView {
                var log: [String] = []
                let popups = allViews(in: view).compactMap { $0 as? NSPopUpButton }
                for (i, p) in popups.enumerated() {
                    log.append("popup \(i): items=\(p.numberOfItems) selected='\(p.titleOfSelectedItem ?? "")' enabled=\(p.isEnabled) frame=\(p.frame) hidden=\(p.isHiddenOrHasHiddenAncestor)")
                }
                if popups.count > 1, case let first = popups[1], first.numberOfItems > 3 {
                    first.selectItem(at: 3)
                    first.menu?.performActionForItem(at: 3) // o mesmo caminho de um clique no item
                    if let action = first.action { NSApp.sendAction(action, to: first.target, from: first) }
                    log.append("selected '\(first.titleOfSelectedItem ?? "")' on popup 1")
                }
                try? log.joined(separator: "\n").write(toFile: report, atomically: true, encoding: .utf8)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                defer { NSApp.terminate(nil) }
                if let report = UserDefaults.standard.string(forKey: "iol_popup_test"), let view = window.contentView,
                   let existing = try? String(contentsOfFile: report, encoding: .utf8) {
                    let popups = allViews(in: view).compactMap { $0 as? NSPopUpButton }
                    let after = popups.prefix(2).map { "after: '\($0.titleOfSelectedItem ?? "")'" }.joined(separator: " | ")
                    try? (existing + "\n" + after + "\n").write(toFile: report, atomically: true, encoding: .utf8)
                }
                guard let view = window.contentView else { return }
                view.layoutSubtreeIfNeeded()
                window.display()
                guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            }
        }
    }

    private static func allViews(in view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { allViews(in: $0) }
    }

    private static func firstScrollView(in view: NSView) -> NSScrollView? {
        if let s = view as? NSScrollView { return s }
        for sub in view.subviews { if let s = firstScrollView(in: sub) { return s } }
        return nil
    }
}
#endif

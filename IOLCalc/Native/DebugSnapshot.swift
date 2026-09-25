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
        if let path = d.string(forKey: "iol_phone_snapshot") {
            // tela inteira na largura de iPhone (390 pt); use com `-iol_force_compact YES -iol_sample YES`
            // (`-iol_alt YES` liga a comparação com o cenário alternativo; `-iol_monovision YES` a monovisão)
            let model = CalculatorModel()
            model.fillSample()
            if d.bool(forKey: "iol_monovision") { model.setDominant(.od); model.setMonovision(true) }
            if d.bool(forKey: "iol_alt") { model.altScenarioOn = true }
            let page = CalculatorPage(model: model, store: CaseStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("phone-snapshot-cases.json")),
                                      showReport: .constant(false), showCases: .constant(false))
            let width = max(320, d.double(forKey: "iol_snapshot_width") == 0 ? 390 : d.double(forKey: "iol_snapshot_width"))
            // (sem o CompactWidthProvider: o GeometryReader dele não tem altura própria no ImageRenderer)
            let renderer = ImageRenderer(content: page.environment(\.isCompactWidth, width < CompactWidthProvider<EmptyView>.threshold)
                                            .frame(width: width).background(Theme.bg))
            renderer.scale = 1.5 // a página inteira é muito alta para passar por TIFF em 2×
            if let cg = renderer.cgImage, let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil) {
                CGImageDestinationAddImage(dest, cg, nil)
                CGImageDestinationFinalize(dest)
            }
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
        // exportar → importar em outra loja
        let store3 = CaseStore(fileURL: url)
        let c3 = store3.saveNew(from: model)
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent(c3.fileName)
        do {
            try CaseFile.encoder.encode(CaseFile(cases: [c3])).write(to: exportURL, options: .atomic)
            let url4 = FileManager.default.temporaryDirectory.appendingPathComponent("iol-cases-import-\(UUID().uuidString).json")
            let store4 = CaseStore(fileURL: url4)
            let n1 = try store4.importCases(from: exportURL)
            let n2 = try store4.importCases(from: exportURL) // repetido: nada novo
            ok = ok && n1 == 1 && n2 == 0 && store4.cases.first?.snapshot == model.snapshot()
            log.append("export/import n1=\(n1) n2=\(n2) equal=\(store4.cases.first?.snapshot == model.snapshot())")
            try? FileManager.default.removeItem(at: url4)
        } catch { ok = false; log.append("export/import error: \(error)") }
        try? FileManager.default.removeItem(at: exportURL)
        // laudo guardado com o caso: salvar com 2 páginas (PDF + imagem), recarregar, ler, trocar por 1,
        // exportar/importar com as páginas embutidas, apagar (a pasta some)
        let url5 = FileManager.default.temporaryDirectory.appendingPathComponent("iol-cases-laudo-\(UUID().uuidString)/cases.json")
        let store5 = CaseStore(fileURL: url5)
        let pdf = Data("%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF".utf8)
        let png: Data = {
            let r = ImageRenderer(content: Color.red.frame(width: 40, height: 30))
            r.scale = 1
            let img = r.nsImage!
            return NSBitmapImageRep(data: img.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        }()
        let pages = [PickedFile(data: pdf, name: "laudo.pdf", type: .pdf), PickedFile(data: png, name: "foto.png", type: .png)]
        let c5 = store5.saveNew(from: model, laudo: pages)
        let dir5 = url5.deletingLastPathComponent().appendingPathComponent("laudos/\(c5.id.uuidString)")
        let files5 = (try? FileManager.default.contentsOfDirectory(atPath: dir5.path))?.sorted() ?? []
        ok = ok && c5.laudo?.map(\.fileName) == ["pagina1.pdf", "pagina2.jpg"] && files5 == ["pagina1.pdf", "pagina2.jpg"]
        log.append("laudo saved pages=\(c5.laudo?.map(\.fileName) ?? []) files=\(files5)")
        Task { @MainActor in
            var ok2 = ok
            let reloaded = CaseStore(fileURL: url5)
            let read = await reloaded.loadLaudo(reloaded.cases.first!)
            ok2 = ok2 && read.count == 2 && read[0].data == pdf && read[1].type == .jpeg && !read[1].data.isEmpty
            log.append("laudo reloaded count=\(read.count) pdfEqual=\(read.first?.data == pdf) jpg=\(read.last?.data.count ?? 0) bytes")
            // atualizar sem laudo mantém; com laudo novo substitui
            model.loadedCaseID = c5.id
            let kept = reloaded.update(from: model, laudo: nil)
            let replaced = reloaded.update(from: model, laudo: [pages[1]])
            let files6 = (try? FileManager.default.contentsOfDirectory(atPath: dir5.path))?.sorted() ?? []
            ok2 = ok2 && kept.laudo?.count == 2 && replaced.laudo?.count == 1 && files6 == ["pagina1.jpg"]
            log.append("laudo update kept=\(kept.laudo?.count ?? 0) replaced=\(replaced.laudo?.count ?? 0) files=\(files6)")
            // exportar → importar noutra loja: as páginas viajam embutidas
            let exp = reloaded.export(replaced)
            ok2 = ok2 && exp.cases.first?.laudo?.first?.base64 != nil
            let expURL = FileManager.default.temporaryDirectory.appendingPathComponent(exp.fileName)
            let url7 = FileManager.default.temporaryDirectory.appendingPathComponent("iol-cases-laudo-imp-\(UUID().uuidString)/cases.json")
            do {
                try CaseFile.encoder.encode(CaseFile(cases: exp.cases)).write(to: expURL, options: .atomic)
                let store7 = CaseStore(fileURL: url7)
                let n = try store7.importCases(from: expURL)
                let read7 = await store7.loadLaudo(store7.cases.first!)
                ok2 = ok2 && n == 1 && store7.cases.first?.laudo?.first?.base64 == nil && read7.count == 1 && read7[0].data == read[1].data
                log.append("laudo export/import n=\(n) pages=\(read7.count) sameBytes=\(read7.first?.data == read[1].data)")
                store7.delete(store7.cases.first!)
                ok2 = ok2 && !FileManager.default.fileExists(atPath: url7.deletingLastPathComponent().appendingPathComponent("laudos/\(replaced.id.uuidString)").path)
                try? FileManager.default.removeItem(at: url7.deletingLastPathComponent())
            } catch { ok2 = false; log.append("laudo export/import error: \(error)") }
            try? FileManager.default.removeItem(at: expURL)
            reloaded.delete(replaced)
            ok2 = ok2 && !FileManager.default.fileExists(atPath: dir5.path)
            log.append("laudo deleted dirGone=\(!FileManager.default.fileExists(atPath: dir5.path))")
            try? FileManager.default.removeItem(at: url5.deletingLastPathComponent())
            log.append(ok2 ? "OK" : "FAIL")
            try? FileManager.default.removeItem(at: url)
            try? log.joined(separator: "\n").write(toFile: out, atomically: true, encoding: .utf8)
        }
    }

    /// Parte sem janela (testes e renders por `ImageRenderer`): roda no `init` do app, porque em
    /// sessões em segundo plano (macOS 27) a janela pode nem aparecer e o `onAppear` não dispara.
    /// Se nenhum `-iol_snapshot` de janela foi pedido, encerra o app ao terminar.
    @MainActor static func runHeadlessIfRequested() {
        let d = UserDefaults.standard
        let keys = ["iol_prep_test", "iol_cases_test", "iol_chart_snapshot", "iol_toric_snapshot", "iol_phone_snapshot",
                    "iol_calcs_snapshot", "iol_report_snapshot", "iol_report_pdf", "iol_sim_snapshot"]
        guard keys.contains(where: { d.string(forKey: $0) != nil }) else { return }
        prepTestIfRequested()
        casesTestIfRequested()
        renderChartIfRequested()
        renderSectionsIfRequested()
        if d.string(forKey: "iol_snapshot") == nil, d.string(forKey: "iol_popup_test") == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
        }
    }

    @MainActor static func runIfRequested() {
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

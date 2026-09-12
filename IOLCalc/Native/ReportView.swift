import SwiftUI
import IOLCore
import PDFKit

// MARK: - Relatório (conteúdo)

/// Relatório de planejamento, porte do `generateReport()` da web: biometria, poder da LIO por
/// olho, visão binocular, tórica, comparador, aviso e assinaturas. Só `Text`/`Grid`, para o
/// `ImageRenderer` conseguir desenhar tudo (PDF, impressão).
struct ReportView: View {
    let model: CalculatorModel
    var date = Date()

    private let ink = Theme.ink
    private let blue = Color(hex: 0x1e40af)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Relatório de Planejamento de LIO").font(.system(size: 20, weight: .bold)).foregroundStyle(ink)
            let name = model.patientName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                Text("Paciente: \(name)").font(.system(size: 15, weight: .bold)).foregroundStyle(ink).padding(.top, 4)
            }
            Text("Catarata · \(Self.stamp(date)) · Calculadora de LIO").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.top, 2)

            heading("1 · Biometria")
            biometryTable

            heading("2 · Poder da LIO")
            HStack(alignment: .top, spacing: 16) {
                powerBlock(.od)
                powerBlock(.oe)
            }

            heading("3 · Visão binocular prevista")
            binocularBlock

            heading("4 · Planejamento tórico")
            HStack(alignment: .top, spacing: 16) {
                toricBlock(.od)
                toricBlock(.oe)
            }

            if let cmp = compareRows {
                heading("5 · Comparação de lentes — \(model.compareEye.rawValue)")
                table(headers: ["Lente", "Poder", "Residual", "Longe", "66 cm", "40 cm", "Disfotopsia"], rows: cmp, leadingLabel: true, compact: true, firstColumnMinWidth: 150)
                sub("AV monocular prevista do \(model.compareEye.rawValue), cada lente com a própria constante A" + (model.astigmatismOn ? " · astigmatismo residual considerado" : "") + ".")
            }

            disclaimer
            signatures
        }
        .font(.system(size: 13))
        .foregroundStyle(ink)
        .padding(24)
        .background(Color.white)
    }

    // MARK: blocos

    private func heading(_ t: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(t).font(.system(size: 14, weight: .bold)).foregroundStyle(blue)
            Rectangle().fill(Theme.brand).frame(height: 2)
        }
        .padding(.top, 18).padding(.bottom, 8)
    }

    private func sub(_ t: String) -> some View {
        Text(t).font(.system(size: 11.5)).foregroundStyle(Color(hex: 0x475569)).padding(.vertical, 1)
            .fixedSize(horizontal: false, vertical: true) // quebra em vez de truncar dentro do HStack
    }

    private var biometryTable: some View {
        func row(_ eye: Eye) -> [String] {
            let f = model[eye]
            func v(_ s: String) -> String { Num.parse(s).map { _ in s } ?? "—" }
            return [eye.rawValue, v(f.al), v(f.k1), v(f.k2), Num.fmt(f.km), v(f.acd), v(f.lt), v(f.wtw), v(f.cct), v(f.tk1), v(f.tk2)]
        }
        return table(headers: ["Olho", "AL", "K1", "K2", "Km", "ACD", "LT", "WTW", "CCT", "TK1", "TK2"], rows: [row(.od), row(.oe)], leadingLabel: true, compact: true)
    }

    @ViewBuilder
    private func powerBlock(_ eye: Eye) -> some View {
        switch model.result(for: eye) {
        case .disabled:
            (Text("\(eye.rawValue): ").bold() + Text("não calculado (desativado).")).frame(maxWidth: .infinity, alignment: .leading)
        case .incomplete:
            (Text("\(eye.rawValue): ").bold() + Text("dados incompletos (preencha AL, K, constante A e selecione a LIO).")).frame(maxWidth: .infinity, alignment: .leading)
        case .plan(let plan):
            VStack(alignment: .leading, spacing: 2) {
                Text("\(eye.rawValue) — \(model[eye].lens?.name ?? "LIO ?")").font(.system(size: 13, weight: .bold))
                Text("Poder sugerido: \(Num.fmt(plan.chosen.power)) D").font(.system(size: 15, weight: .bold))
                sub("alvo \(Num.fmt(plan.target)) D · refração prevista \(Num.fmt(plan.chosen.residual)) D · A \(Num.fmt(plan.aConstant))"
                    + (plan.deltaA != 0 ? " → Aef \(Num.fmt(plan.effectiveA))" : "") + " · método \(plan.method.shortLabel)")
                table(headers: ["Fórmula (p/ alvo)", "Poder"],
                      rows: plan.rows.map { [$0.formula.rawValue, "\(Num.fmt($0.targetPower)) D"] },
                      leadingLabel: true, highlight: plan.rows.map(\.isRecommended), small: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var binocularBlock: some View {
        if let far = model.binocularVA(at: DefocusModel.farDefocus),
           let inter = model.binocularVA(at: DefocusModel.intermediateDefocus),
           let near = model.binocularVA(at: DefocusModel.nearDefocus) {
            let s = DefocusModel.snellen(fromLogMAR:)
            table(headers: ["Longe", "Interm. (66cm)", "Perto (40cm)", "Estereopsia"],
                  rows: [[s(far), s(inter), s(near), model.stereopsis() ?? "—"]], small: true)
            sub("Curva binocular" + (model.astigmatismOn
                ? " · astigmatismo considerado (OD \(Num.fmt(model.od.cylinderValue)) D / OE \(Num.fmt(model.oe.cylinderValue)) D)" : "") + ".")
        } else {
            sub("Selecione LIO em ao menos um olho.")
        }
    }

    private func toricBlock(_ eye: Eye) -> some View {
        let plan = model.toricPlan(eye)
        return VStack(alignment: .leading, spacing: 2) {
            if plan.totalMagnitude < 0.01 && plan.input.iolCylinder == 0 {
                Text(eye.rawValue).font(.system(size: 13, weight: .bold))
                sub("sem dados de astigmatismo.")
            } else {
                let platform = model.toricPlatform(eye)
                Text("\(eye.rawValue) — tórica").font(.system(size: 13, weight: .bold))
                Group {
                    if plan.input.iolCylinder > 0 {
                        Text("LIO tórica ") + Text("\(Num.fmt(plan.input.iolCylinder)) D").bold()
                            + Text(" (\(platform.name.split(separator: " ").first.map(String.init) ?? platform.name)) alinhada a ")
                            + Text("\(Num.fmt(PowerPlanner.roundHalfUp(plan.input.iolAxis), 0))°").bold()
                    } else {
                        Text("sem cilindro definido")
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                sub("astig. total \(Num.fmt(plan.totalMagnitude)) D @ \(Num.fmt(PowerPlanner.roundHalfUp(plan.totalAxis), 0))° (\(Self.modeText(plan.input.model))) · SIA \(Num.fmt(plan.input.sia)) D @ \(Num.fmt(PowerPlanner.roundHalfUp(plan.input.siaAxis), 0))°")
                (Text("residual previsto ").font(.system(size: 11.5)) + Text("\(Num.fmt(plan.residualMagnitude)) D @ \(Num.fmt(PowerPlanner.roundHalfUp(plan.residualAxis), 0))°").font(.system(size: 11.5, weight: .bold))
                 + Text(" · razão \(Num.fmt(plan.input.ratio))").font(.system(size: 11.5)))
                    .foregroundStyle(Color(hex: 0x475569))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func modeText(_ m: CornealAstigmatismModel) -> String {
        switch m {
        case .anterior: return "córnea anterior"
        case .abulafiaKoch: return "total est. Abulafia-Koch"
        case .naeserSavini: return "total est. Næser-Savini"
        case .total: return "total medido (TK/K post.)"
        }
    }

    private var compareRows: [[String]]? {
        let picks = [model.compareA, model.compareB].compactMap { model.compare($0) }
        guard picks.count == 2 else { return nil }
        return picks.map { c in
            let l = c.lens
            func va(_ d: Double) -> String {
                DefocusModel.snellen(fromLogMAR: DefocusModel.monocularVA(curve: l.defocusValues, residual: c.residual, defocus: d, cylinder: c.cylinder))
            }
            return [l.name, c.power.map { "\(Num.fmt($0)) D" } ?? "—", "\(Num.fmt(c.residual)) D",
                    va(DefocusModel.farDefocus), va(DefocusModel.intermediateDefocus), va(DefocusModel.nearDefocus),
                    ["baixa", "baixa-mod", "moderada", "alta"][l.dysphotopsia]]
        }
    }

    private var disclaimer: some View {
        (Text("Ferramenta de apoio à decisão — não substitui o julgamento clínico. ").bold()
         + Text("Fórmulas publicadas (SRK/T, T2, Holladay 1 ± Wang-Koch, Hoffer Q, Haigis, Castrop). Curvas de defocus/binocular e o cálculo tórico são estimativas; confirme a LIO tórica e o eixo na calculadora oficial do fabricante (Barrett Toric)."))
            .font(.system(size: 11)).foregroundStyle(Color(hex: 0x92400e))
            .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xfffbeb))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: 0xfde68a)))
            .padding(.top, 16)
    }

    private var signatures: some View {
        HStack {
            signature("Assinatura do cirurgião")
            Spacer()
            signature("Paciente")
        }
        .padding(.top, 34)
    }

    private func signature(_ t: String) -> some View {
        VStack(spacing: 4) {
            Rectangle().fill(Color(hex: 0x94a3b8)).frame(height: 1)
            Text(t).font(.system(size: 11)).foregroundStyle(Color(hex: 0x475569))
        }
        .frame(maxWidth: 300)
    }

    // MARK: tabela

    /// Tabela com bordas finas: cabeçalho cinza, células centradas; `leadingLabel` deixa a primeira
    /// coluna alinhada à esquerda e em negrito; `highlight` pinta linhas (fórmulas recomendadas).
    /// `compact`: fonte 11 e menos recuo (tabelas largas); `firstColumnMinWidth` reserva espaço para nomes.
    private func table(headers: [String], rows: [[String]], leadingLabel: Bool = false, highlight: [Bool]? = nil,
                       small: Bool = false, compact: Bool = false, firstColumnMinWidth: CGFloat? = nil) -> some View {
        let border = Theme.line
        let fs: CGFloat = compact ? 11 : (small ? 11.5 : 12)
        let pad: CGFloat = compact ? 4 : 7
        return Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(Array(headers.enumerated()), id: \.offset) { j, h in
                    Text(h).font(.system(size: compact ? 10.5 : (small ? 11 : 12), weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(minWidth: j == 0 ? firstColumnMinWidth : nil, maxWidth: .infinity)
                        .padding(.horizontal, pad).padding(.vertical, 5)
                        .background(Theme.bg).border(border, width: 0.5)
                }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                let bg = (highlight?[i] ?? false) ? Theme.okBg : Color.white
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { j, cell in
                        let lbl = leadingLabel && j == 0
                        Text(cell).font(.system(size: fs, weight: lbl ? .bold : .regular))
                            .lineLimit(lbl ? 2 : 1).minimumScaleFactor(0.7)
                            .frame(minWidth: j == 0 ? firstColumnMinWidth : nil, maxWidth: .infinity, alignment: lbl ? .leading : .center)
                            .padding(.horizontal, pad).padding(.vertical, 5)
                            .background(bg).border(border, width: 0.5)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    static func stamp(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f.string(from: d)
    }
}

// MARK: - PDF

enum ReportPDF {
    /// A4 em pontos.
    static let pageSize = CGSize(width: 595, height: 842)
    static let margin: CGFloat = 20

    /// Renderiza o relatório em PDF A4 paginado (o conteúdo é desenhado uma vez por página,
    /// deslocado). Deve rodar na main actor (`ImageRenderer`).
    @MainActor
    static func make(model: CalculatorModel, date: Date = Date()) -> Data {
        let width = pageSize.width - 2 * margin
        let renderer = ImageRenderer(content: ReportView(model: model, date: date).frame(width: width))
        let data = NSMutableData()
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: pageSize)
            guard let consumer = CGDataConsumer(data: data), let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            let usable = pageSize.height - 2 * margin
            let pages = max(1, Int((size.height / usable).rounded(.up)))
            for page in 0..<pages {
                pdf.beginPDFPage(nil)
                pdf.saveGState()
                // recorta à área útil e desloca o conteúdo para a página; o CGContext do PDF tem origem embaixo
                pdf.clip(to: CGRect(x: margin, y: margin, width: width, height: usable))
                pdf.translateBy(x: margin, y: pageSize.height - margin - size.height + CGFloat(page) * usable)
                draw(pdf)
                pdf.restoreGState()
                pdf.endPDFPage()
            }
            pdf.closePDF()
        }
        return data as Data
    }

    static func fileName(for model: CalculatorModel) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        let n = model.patientName.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        return "Relatorio-LIO-" + (n.isEmpty ? "" : n + "-") + f.string(from: Date()) + ".pdf"
    }

    static func print(_ data: Data) {
        #if os(iOS)
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = "Relatório de LIO"
        controller.printInfo = info
        controller.printingItem = data
        controller.present(animated: true)
        #else
        guard let doc = PDFDocument(data: data) else { return }
        let info = NSPrintInfo.shared
        info.paperSize = pageSize
        if let op = doc.printOperation(for: info, scalingMode: .pageScaleNone, autoRotate: true) {
            op.showsPrintPanel = true
            op.showsProgressPanel = true
            if let window = NSApp.keyWindow { op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil) } else { op.run() }
        }
        #endif
    }
}

// MARK: - Sheet

/// Relatório nativo: pré-visualização rolável, impressão e PDF (compartilhar/salvar).
struct NativeReportSheet: View {
    let model: CalculatorModel
    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL?
    @State private var pdfData: Data?
    @State private var error: String?
    private let date = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                ReportView(model: model, date: date)
                    .frame(width: ReportPDF.pageSize.width - 2 * ReportPDF.margin)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                    .padding(20)
                    .frame(maxWidth: .infinity)
            }
            .background(Theme.bg)
            .navigationTitle("Relatório")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Imprimir", systemImage: "printer") { if let pdfData { ReportPDF.print(pdfData) } }
                        .disabled(pdfData == nil)
                    if let pdfURL {
                        ShareLink(item: pdfURL) { Label("PDF", systemImage: "square.and.arrow.up") }
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .task { export() }
            .overlay(alignment: .bottom) {
                if let error { Text(error).font(.system(size: 12)).foregroundStyle(Theme.errInk).padding(8).background(Theme.errBg) }
            }
        }
        #if os(macOS)
        .frame(minWidth: 700, idealWidth: 760, minHeight: 700, idealHeight: 880)
        #endif
    }

    @MainActor
    private func export() {
        let data = ReportPDF.make(model: model, date: date)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(ReportPDF.fileName(for: model))
        do {
            try data.write(to: url, options: .atomic)
            pdfData = data
            pdfURL = url
        } catch {
            self.error = error.localizedDescription
        }
    }
}

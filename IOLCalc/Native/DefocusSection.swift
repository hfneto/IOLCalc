import SwiftUI
import Charts
import IOLCore

/// Uma curva do gráfico de defocus: pontos (defocus, logMAR) já amostrados em `DefocusModel.plotAxis`.
struct DefocusSeries: Identifiable {
    let id: String
    let color: Color
    let width: CGFloat
    /// Tracejada em toda a extensão (curvas monoculares na seção 5).
    let dashed: Bool
    let points: [(x: Double, y: Double)]

    /// Trechos além de −3 D são extrapolação (tracejados, como na web).
    var measured: [(x: Double, y: Double)] { points.filter { $0.x >= DefocusModel.extrapolationFrom } }
    var extrapolated: [(x: Double, y: Double)] { points.filter { $0.x <= DefocusModel.extrapolationFrom } }

    static func sampled(id: String, color: Color, width: CGFloat, dashed: Bool = false, _ f: (Double) -> Double?) -> DefocusSeries? {
        var pts: [(Double, Double)] = []
        for d in DefocusModel.plotAxis {
            guard let v = f(d) else { return nil }
            pts.append((d, v))
        }
        return DefocusSeries(id: id, color: color, width: width, dashed: dashed, points: pts)
    }
}

/// Gráfico de defocus (Swift Charts). Os eixos são desenhados negados para reproduzir a web:
/// X de +1 (esquerda) a −4 D (direita) e Y invertido (logMAR menor = melhor, em cima).
struct DefocusChart: View {
    let series: [DefocusSeries]
    var yTitle = "AV (logMAR) — menor é melhor"

    var body: some View {
        Chart {
            ForEach(series) { s in
                if s.dashed {
                    ForEach(Array(s.points.enumerated()), id: \.offset) { _, p in
                        LineMark(x: .value("Defocus", -p.x), y: .value("logMAR", -p.y), series: .value("Série", s.id))
                    }
                    .foregroundStyle(s.color).lineStyle(StrokeStyle(lineWidth: s.width, dash: [5, 3])).interpolationMethod(.catmullRom)
                } else {
                    ForEach(Array(s.measured.enumerated()), id: \.offset) { _, p in
                        LineMark(x: .value("Defocus", -p.x), y: .value("logMAR", -p.y), series: .value("Série", s.id))
                    }
                    .foregroundStyle(s.color).lineStyle(StrokeStyle(lineWidth: s.width)).interpolationMethod(.catmullRom)
                    ForEach(Array(s.extrapolated.enumerated()), id: \.offset) { _, p in
                        LineMark(x: .value("Defocus", -p.x), y: .value("logMAR", -p.y), series: .value("Série", s.id + " (extrapolado)"))
                    }
                    .foregroundStyle(s.color).lineStyle(StrokeStyle(lineWidth: s.width, dash: [4, 4])).interpolationMethod(.catmullRom)
                }
            }
        }
        .chartXScale(domain: -1.0...4.0)
        .chartYScale(domain: -DefocusModel.plotLogMARRange.upperBound...(-DefocusModel.plotLogMARRange.lowerBound))
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .stride(by: 0.5)) { v in
                AxisGridLine()
                AxisTick()
                AxisValueLabel { if let d = v.as(Double.self) { Text(Self.axisLabel(-d)).font(.system(size: 11)) } }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .stride(by: 0.1)) { v in
                AxisGridLine()
                AxisTick()
                AxisValueLabel { if let l = v.as(Double.self) { Text(Num.fmt(-l + 0, 1)).font(.system(size: 11)) } }
            }
        }
        .chartXAxisLabel("Defocus (D) — negativo = perto · tracejado: extrapolado", alignment: .center)
        .chartYAxisLabel(yTitle, position: .leading)
        .chartLegend(.hidden)
    }

    /// Rótulo do eixo X como na web: zeros finais removidos ("0,75", "-3", "0").
    static func axisLabel(_ d: Double) -> String {
        var s = String(format: "%.2f", d)
        if s.contains(".") { while s.hasSuffix("0") { s.removeLast() }; if s.hasSuffix(".") { s.removeLast() } }
        if s == "-0" { s = "0" }
        return s.replacingOccurrences(of: ".", with: ",")
    }
}

// MARK: - 5 · Curva de defocus & visão binocular

struct DefocusSection: View {
    @Bindable var model: CalculatorModel

    var body: some View {
        SectionCard(title: "5 · Curva de defocus & visão binocular", trailing: AnyView(toggles)) {
            HStack(spacing: 14) {
                legendDot(Theme.od, "OD"); legendDot(Theme.oe, "OE"); legendDot(Theme.bino, "Binocular")
                if model.altScenarioOn { legendDot(Theme.alt, "Alternativa") }
                Spacer()
                HelpButton(topic: .defocusSlider)
            }
            altRow
            if series.isEmpty {
                MutedText("selecione a LIO de ao menos um olho para ver as curvas")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                DefocusChart(series: series).frame(height: 320)
            }
            EyePair { eye in
                ResidualCard(eye: eye, model: model)
            }
            metrics
            MutedText("As curvas do catálogo são o resultado binocular dos estudos dos fabricantes: a AV monocular é a curva mais a penalidade de somação, e a binocular do paciente é a combinação das duas (em olhos simétricos reproduz a curva publicada, nunca melhor). Anisometropia reduz o ganho binocular. Trecho além de −3,0 D é extrapolado (tracejado).", size: 11.5)
        }
    }

    private var toggles: some View {
        FlowLayout(spacing: 14) {
            Toggle("considerar astigmatismo", isOn: $model.astigmatismOn)
            Toggle("mostrar olhos individuais", isOn: $model.showMonocular)
        }
        #if os(macOS)
        .toggleStyle(.checkbox)
        #else
        .toggleStyle(.button)
        #endif
        .font(.system(size: 12)).foregroundStyle(Theme.ink)
    }

    /// "Comparar com…": o cenário oposto ao plano (monovisão monofocal ou multifocal bilateral),
    /// com a lente de referência escolhida aqui (padrão em Configurações › Padrões).
    private var altRow: some View {
        FlowLayout(spacing: 12) {
            Toggle("comparar com \(model.altTitle)", isOn: $model.altScenarioOn)
                #if os(macOS)
                .toggleStyle(.checkbox)
                #else
                .toggleStyle(.button)
                #endif
                .font(.system(size: 12)).foregroundStyle(Theme.ink)
            if model.altScenarioOn {
                HStack(spacing: 6) {
                    MutedText(model.altIsMonovision ? "monofocal:" : "multifocal:")
                    CompactMenuPicker(selection: $model.altLensID, options: altChoices.map { (id: $0.id, title: $0.name) })
                }
                if model.altIsMonovision {
                    MutedText("alvos \(model.dominantEye?.rawValue ?? "OD") 0,00 · \(model.dominantEye == .oe ? "OD" : "OE") \(Num.fmt(-PlanningDefaults.shared.monovisionValueOr(model.monovisionAmount))) D", size: 11.5)
                }
                HelpButton(topic: .monovision)
            }
        }
    }

    /// Lentes oferecidas para o cenário alternativo: monofocais (monovisão) ou as favoritas não
    /// monofocais (multifocal bilateral); a escolhida entra mesmo fora da lista.
    private var altChoices: [IOLLens] {
        let favs = LensPreferences.shared.favorites
        var list: [IOLLens]
        if model.altIsMonovision {
            list = LensCatalog.all.filter { $0.category == .monofocal || $0.category == .enhancedMonofocal }
        } else {
            list = LensCatalog.all.filter { favs.contains($0.id) && $0.category != .monofocal && $0.category != .enhancedMonofocal }
        }
        if let cur = model.altLens, !list.contains(where: { $0.id == cur.id }) { list.insert(cur, at: 0) }
        return list
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 11, height: 11)
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.ink)
        }
    }

    private var series: [DefocusSeries] {
        var out: [DefocusSeries] = []
        let od = DefocusSeries.sampled(id: "OD", color: Theme.od, width: 1.5, dashed: true) { model.monocularVA(.od, at: $0) }
        let oe = DefocusSeries.sampled(id: "OE", color: Theme.oe, width: 1.5, dashed: true) { model.monocularVA(.oe, at: $0) }
        if model.showMonocular { if let od { out.append(od) }; if let oe { out.append(oe) } }
        if let bino = DefocusSeries.sampled(id: "Binocular", color: Theme.bino, width: 3) { model.binocularVA(at: $0) } {
            out.append(bino)
        }
        if model.altScenarioOn, let alt = DefocusSeries.sampled(id: "Alternativa", color: Theme.alt, width: 2.5, dashed: true) { model.altBinocularVA(at: $0) } {
            out.append(alt)
        }
        return out
    }

    private var metrics: some View {
        Group {
            if let far = model.binocularVA(at: DefocusModel.farDefocus),
               let inter = model.binocularVA(at: DefocusModel.intermediateDefocus),
               let near = model.binocularVA(at: DefocusModel.nearDefocus) {
                MetricGrid {
                    MetricCard(label: "Longe (∞)", value: DefocusModel.snellen(fromLogMAR: far), note: "\(Num.fmt(far)) logMAR")
                    MetricCard(label: "Intermediária 66 cm", value: DefocusModel.snellen(fromLogMAR: inter), note: "\(Num.fmt(inter)) logMAR")
                    MetricCard(label: "Perto 40 cm", value: DefocusModel.snellen(fromLogMAR: near), note: "\(Num.fmt(near)) logMAR · \(DefocusModel.jaeger(fromLogMAR: near))")
                    MetricCard(label: "Estereopsia (longe)", value: model.stereopsis() ?? "—", note: "estimada")
                }
                if model.altScenarioOn, let lens = model.altLens,
                   let aFar = model.altBinocularVA(at: DefocusModel.farDefocus),
                   let aInter = model.altBinocularVA(at: DefocusModel.intermediateDefocus),
                   let aNear = model.altBinocularVA(at: DefocusModel.nearDefocus) {
                    (Text("Alternativa · \(model.altTitle) (\(lens.name)): ").bold()
                     + Text("longe \(DefocusModel.snellen(fromLogMAR: aFar)) · 66 cm \(DefocusModel.snellen(fromLogMAR: aInter)) · 40 cm \(DefocusModel.snellen(fromLogMAR: aNear)) (\(DefocusModel.jaeger(fromLogMAR: aNear)))")
                     + Text(" · plano: longe \(DefocusModel.snellen(fromLogMAR: far)) · 66 cm \(DefocusModel.snellen(fromLogMAR: inter)) · 40 cm \(DefocusModel.snellen(fromLogMAR: near))"))
                        .font(.system(size: 12)).foregroundStyle(Theme.ink)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.alt.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.alt.opacity(0.5)))
                }
            } else {
                MutedText("selecione a LIO de ao menos um olho para ver as curvas e a simulação")
            }
        }
    }
}

/// Grade de métricas: 4 por linha no desktop, 2 no iPhone.
struct MetricGrid<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) { content }
    }
}

private struct ResidualCard: View {
    let eye: Eye
    @Bindable var model: CalculatorModel

    var body: some View {
        EyeCard(eye: eye, title: "Ajuste residual \(eye.rawValue)") {
            MutedText("Residual previsto (cálculo): \(Num.fmt(model.predictedResidual(eye))) D · régua = alvo da seção 2 (arraste p/ simular)")
            HStack(spacing: 4) {
                MutedText("Refração usada no gráfico (seção 3 + ajuste):")
                Text(model.eyeActive(eye) ? "\(Num.fmt(model.effectiveResidual(eye))) D" : "—").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.ink)
            }
            HStack(spacing: 10) {
                Slider(value: Binding(get: { model[eye].residualSlider }, set: { model[eye].residualSlider = ($0 * 4).rounded() / 4 }),
                       in: EyeForm.sliderRange, step: 0.25)
                    .tint(Theme.accent(eye))
                Text("\(Num.fmt(model[eye].residualSlider)) D").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink)
                    .frame(width: 64, alignment: .trailing)
            }
            if model.astigmatismOn {
                HStack(alignment: .top, spacing: 8) {
                    NumberField(label: "Astig. residual (D)", text: Binding(get: { model[eye].cylinderText },
                                                                          set: { model[eye].cylinderTouched = true; model[eye].cylinder = $0 }),
                                placeholder: "ex. 0,75")
                    NumberField(label: "Eixo (°)", text: Binding(get: { model[eye].cylinderAxis }, set: { model[eye].cylinderAxis = $0 }))
                }
            }
        }
    }
}

// MARK: - Comparar 2 lentes no mesmo olho (gaveta)

struct CompareDrawer: View {
    @Bindable var model: CalculatorModel
    @State private var open = UserDefaults.standard.bool(forKey: "iol_sample")
    /// Qual seletor pediu "Outra LIO…" (catálogo completo; sem constante manual no comparador).
    @State private var other: Slot?
    private enum Slot: String, Identifiable { case a, b; var id: String { rawValue } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $open) {
                content.padding(.top, 8)
            } label: {
                HStack(spacing: 8) {
                    Text("⚖ Comparar 2 lentes no mesmo olho").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Chip(text: "gaveta")
                }
            }
            .tint(Theme.muted)
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20))
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
        .sheet(item: $other) { slot in
            LensChooserSheet(title: "Outra LIO · lente \(slot.rawValue.uppercased())", initialCustom: nil, allowCustom: false,
                             onPick: { id in if slot == .a { model.compareA = id } else { model.compareB = id } })
        }
    }

    private var picks: [(String, CalculatorModel.CompareResult)] {
        [("A", model.compareA), ("B", model.compareB)].compactMap { tag, id in model.compare(id).map { (tag, $0) } }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            AdaptiveHStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    FieldLabel(text: "Olho")
                    Picker("", selection: $model.compareEye) { ForEach(Eye.allCases) { Text($0.rawValue).tag($0) } }
                        .labelsHidden().pickerStyle(.segmented).fixedSize()
                }
                VStack(alignment: .leading, spacing: 3) { FieldLabel(text: "Lente A"); LensPicker(selection: $model.compareA, placeholder: "— selecione —", onOther: { other = .a }).pickerStyle(.menu).frame(maxWidth: 320, alignment: .leading) }
                VStack(alignment: .leading, spacing: 3) { FieldLabel(text: "Lente B"); LensPicker(selection: $model.compareB, placeholder: "— selecione —", onOther: { other = .b }).pickerStyle(.menu).frame(maxWidth: 320, alignment: .leading) }
            }
            let picks = picks
            if picks.isEmpty {
                MutedText("selecione as lentes A e B para comparar").frame(maxWidth: .infinity, minHeight: 60)
            } else {
                DefocusChart(series: picks.compactMap { tag, c in
                    DefocusSeries.sampled(id: "\(tag) · \(c.lens.name)", color: Color(hex: c.lens.colorHex), width: 2.5) {
                        DefocusModel.monocularVA(curve: c.lens.defocusValues, residual: c.residual, defocus: $0, cylinder: c.cylinder)
                    }
                }, yTitle: "AV monocular (logMAR) — menor é melhor")
                .frame(height: 300)
                EyePairLike { ForEach(picks, id: \.0) { tag, c in compareCard(tag, c) } }
            }
            MutedText("Curvas monoculares do olho escolhido, cada lente com o poder sugerido para a sua própria constante A (e o astigmatismo residual do olho, se ativado). Sem biometria, a curva fica posicionada no alvo.", size: 11.5)
        }
    }

    private func compareCard(_ tag: String, _ c: CalculatorModel.CompareResult) -> some View {
        let lens = c.lens
        let far = DefocusModel.monocularVA(curve: lens.defocusValues, residual: c.residual, defocus: DefocusModel.farDefocus, cylinder: c.cylinder)
        let inter = DefocusModel.monocularVA(curve: lens.defocusValues, residual: c.residual, defocus: DefocusModel.intermediateDefocus, cylinder: c.cylinder)
        let near = DefocusModel.monocularVA(curve: lens.defocusValues, residual: c.residual, defocus: DefocusModel.nearDefocus, cylinder: c.cylinder)
        let dA = model.currentDeltaA
        return VStack(alignment: .leading, spacing: 4) {
            Text("LENTE \(tag)").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
            HStack(spacing: 6) {
                Text(lens.name).font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.ink)
                Chip(text: lens.type)
            }
            MutedText("\(lens.manufacturer) · A \(Num.fmt(lens.aConstant))\(dA != 0 ? " → \(Num.fmt(lens.aConstant + dA))" : "") · disfotopsia \(["baixa", "baixa-mod", "moderada", "alta"][lens.dysphotopsia])")
            if let p = c.power {
                (Text("Poder sugerido: ") + Text("\(Num.fmt(p)) D").bold() + Text(" · residual \(Num.fmt(c.residual)) D"))
                    .font(.system(size: 13)).foregroundStyle(Theme.ink)
            } else {
                Text("sem biometria — curva posicionada no alvo").font(.system(size: 13)).foregroundStyle(Theme.warn)
            }
            (Text("Longe ") + Text(DefocusModel.snellen(fromLogMAR: far)).bold() + Text(" · 66 cm ") + Text(DefocusModel.snellen(fromLogMAR: inter)).bold()
             + Text(" · 40 cm ") + Text(DefocusModel.snellen(fromLogMAR: near)).bold() + Text(" (\(DefocusModel.jaeger(fromLogMAR: near)))"))
                .font(.system(size: 12.5)).foregroundStyle(Theme.ink)
            PillButton(title: "✓ usar esta no \(model.compareEye.rawValue)") { model.applyCompare(lens.id) }
                .padding(.top, 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(alignment: .top) { Rectangle().fill(Color(hex: lens.colorHex)).frame(height: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
    }
}

/// Mesmo comportamento do `EyePair` para conteúdo arbitrário (lado a lado ou empilhado).
struct EyePairLike<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.isCompactWidth) private var stacked
    var body: some View {
        if stacked { VStack(spacing: 12) { content } } else { HStack(alignment: .top, spacing: 12) { content } }
    }
}

extension Color {
    init(hex string: String) {
        var s = string.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        self.init(hex: UInt32(s, radix: 16) ?? 0x6b7280)
    }
}

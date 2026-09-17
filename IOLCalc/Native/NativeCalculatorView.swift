import SwiftUI
import IOLCore
import UniformTypeIdentifiers

/// A calculadora inteira em SwiftUI: biometria, lentes e alvo, poder da LIO, calculadoras oficiais,
/// defocus e binocular, comparador, simulação visual e tórica, calculando com o `IOLCore`.
struct NativeCalculatorView: View {
    @State private var model = CalculatorModel()
    @State private var store = CaseStore(useCloud: true)
    @State private var reader = AIReaderState()
    @State private var showReport = false
    @State private var showCases = false
    @State private var showSettings = false
    @Environment(\.isCompactWidth) private var compact

    var body: some View {
        // O provedor de largura fica DENTRO do inspector: com o laudo aberto ao lado, a coluna da
        // calculadora encolhe e passa ao layout de uma coluna (senão a página de duas colunas
        // estourava e era cortada dos dois lados).
        CompactWidthProvider { page }
        // O laudo lido fica ao lado da calculadora (Mac/iPad) ou numa folha (iPhone), para conferir
        // os valores linha a linha antes de calcular.
        .inspector(isPresented: $reader.showLaudo) {
            LaudoInspector(files: reader.laudo, onOpenFile: { reader.open($0) }, onClose: { reader.showLaudo = false })
                .inspectorColumnWidth(min: 320, ideal: 440, max: 800)
        }
        .onChange(of: reader.laudoJustRead) { _, just in
            guard just else { return }
            reader.laudoJustRead = false
            // Com largura (janela/iPad), abre sozinho; no iPhone a folha cobriria os campos — fica
            // no botão "Ver laudo". `compact` aqui é o da janela inteira (provedor do RootView).
            if !compact { reader.showLaudo = true }
        }
        .sheet(isPresented: $showReport) { NativeReportSheet(model: model) }
        .sheet(isPresented: $showCases) { CasesSheet(model: model, store: store, reader: reader) }
        .sheet(isPresented: $showSettings) { SettingsSheet(reader: reader) }
    }

    private var page: some View {
        ScrollViewReader { proxy in
            ScrollView {
                CalculatorPage(model: model, store: store, reader: reader, showReport: $showReport, showCases: $showCases, showSettings: $showSettings)
            }
            #if os(iOS)
            // Fundo translúcido atrás da barra de status (o conteúdo rola por baixo do relógio): a
            // faixa de altura zero fica logo abaixo da área segura e o fundo se estende para cima.
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0).background(.ultraThinMaterial)
            }
            #endif
            #if DEBUG
            // `-iol_scroll_section <1…8>`: rola até a seção ao abrir (capturas no simulador).
            // `-iol_laudo_file <caminho>`: abre o arquivo no painel do laudo, como se tivesse sido lido.
            .onAppear {
                if let path = UserDefaults.standard.string(forKey: "iol_laudo_file"),
                   let data = FileManager.default.contents(atPath: path) {
                    let url = URL(fileURLWithPath: path)
                    reader.laudo = [PickedFile(data: data, name: url.lastPathComponent, type: UTType(filenameExtension: url.pathExtension))]
                    reader.status = .init(kind: .ok, text: "Laudo lido. Confira os valores antes de calcular — abra o laudo ao lado com \"Ver laudo\".")
                    reader.laudoJustRead = true
                }
                let n = UserDefaults.standard.integer(forKey: "iol_scroll_section")
                guard n > 0 else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { proxy.scrollTo(n, anchor: .top) }
            }
            #endif
        }
        .background(Theme.bg)
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
    }
}

/// O conteúdo da página (fora do `ScrollView`, para o `ImageRenderer` de depuração conseguir desenhá-lo).
struct CalculatorPage: View {
    @Bindable var model: CalculatorModel
    let store: CaseStore
    var reader = AIReaderState()
    @Binding var showReport: Bool
    @Binding var showCases: Bool
    var showSettings: Binding<Bool> = .constant(false)
    @Environment(\.isCompactWidth) private var compact

    var body: some View {
        VStack(spacing: 16) {
            topBar
            BiometrySection(model: model, reader: reader).id(1)
            LensSection(model: model).id(2)
            PowerSection(model: model).id(3)
            CalculatorsSection(model: model).id(4)
            DefocusSection(model: model).id(5)
            CompareDrawer(model: model).id(6)
            SimulationSection(model: model).id(7)
            ToricSection(model: model).id(8)
            MutedText("Recomendação por AL: olho curto (<22 mm) → Hoffer Q / Haigis / Castrop · médio → todas · longo (>26 mm) → Holladay 1 com ajuste Wang-Koch / T2 / Haigis / Castrop. A sugestão é a mediana das fórmulas recomendadas.", size: 11.5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(EdgeInsets(top: compact ? 12 : 24, leading: compact ? 12 : 32, bottom: 24, trailing: compact ? 12 : 32))
        .frame(maxWidth: 1200)
        .frame(maxWidth: .infinity)
    }

    /// Paciente, relatório e casos salvos. No iPhone os botões descem para uma segunda linha.
    private var topBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { patientField; actions }
            VStack(spacing: 8) { patientField; actions.frame(maxWidth: .infinity, alignment: .leading) }
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            PillButton(title: "Relatório", systemImage: "doc.text", primary: true) { showReport = true }
            PillButton(title: store.contains(model.loadedCaseID) ? "Casos · aberto" : "Casos", systemImage: "tray.full") { showCases = true }
            if reader.laudoLoading {
                PillButton(title: "Laudo · baixando…", systemImage: "icloud.and.arrow.down") {}
            } else if !reader.laudo.isEmpty {
                PillButton(title: reader.showLaudo ? "Laudo · aberto" : "Laudo", systemImage: "doc.text.magnifyingglass") { reader.showLaudo.toggle() }
            }
            Button { showSettings.wrappedValue = true } label: {
                Image(systemName: "gearshape").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.brand)
                    .padding(.horizontal, 9).padding(.vertical, 8)
                    .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line))
            }
            .buttonStyle(.plain)
            .help("Configurações: lentes favoritas, leitura por IA e ajuda")
            .accessibilityLabel("Configurações")
        }
        .fixedSize()
    }

    private var patientField: some View {
        HStack(spacing: 10) {
            FieldLabel(text: "Paciente")
            TextField("nome do paciente (opcional — sai no relatório)", text: $model.patientName)
                .textFieldStyle(.plain).font(.system(size: 14)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
                // Largura ideal limitada: o `ViewThatFits` mede o tamanho ideal, e o campo com o
                // placeholder longo fazia a linha "caber" e estourar dos dois lados.
                .frame(minWidth: 160, idealWidth: 360, maxWidth: .infinity)
        }
    }
}

// MARK: - 1 · Biometria

struct BiometrySection: View {
    @Bindable var model: CalculatorModel
    @Bindable var reader: AIReaderState
    @Environment(\.isCompactWidth) private var compact

    var body: some View {
        SectionCard(title: "1 · Biometria", trailing: AnyView(
            HStack(spacing: 8) {
                AIReadControls(model: model, reader: reader)
                PillButton(title: "Limpar") { model.clearBiometry(); reader.clear() }
            }
        )) {
            if let status = reader.status {
                AdaptiveHStack(alignment: .center, spacing: 8) {
                    AIReadControls.StatusView(status: status)
                    if !reader.laudo.isEmpty, !reader.showLaudo {
                        PillButton(title: "Ver laudo", systemImage: "doc.text.magnifyingglass", primary: true) { reader.showLaudo = true }
                            .fixedSize()
                    }
                }
            }
            EyePair { eye in
                BiometryCard(eye: eye, form: binding(eye))
            }
            MutedText("Edite qualquer campo. ACD é necessária para o Haigis; LT e CCT refinam a Castrop. Astigmatismo (ΔK) e TK são só informativos aqui — o planejamento tórico usa TK quando medido.", size: 11.5)
            AIReadControls.Advanced(reader: reader)
        }
    }

    private func binding(_ eye: Eye) -> Binding<EyeForm> {
        Binding(get: { model[eye] }, set: { model[eye] = $0 })
    }
}

private struct BiometryCard: View {
    let eye: Eye
    @Binding var form: EyeForm

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 8)]

    var body: some View {
        EyeCard(eye: eye) {
            LazyVGrid(columns: columns, spacing: 8) {
                NumberField(label: "AL (mm)", text: $form.al)
                NumberField(label: "K1 (D)", text: $form.k1)
                NumberField(label: "K2 (D)", text: $form.k2)
                NumberField(label: "Eixo K2 (°)", text: $form.kAxis, placeholder: "curvo")
                NumberField(label: "ACD (mm)", text: $form.acd)
                NumberField(label: "LT (mm)", text: $form.lt)
                NumberField(label: "WTW (mm)", text: $form.wtw)
                NumberField(label: "CCT (µm)", text: $form.cct, placeholder: "paquimetria", highlighted: !form.cct.isEmpty)
                if form.showTK || form.hasTK {
                    NumberField(label: "TK1 (D)", text: $form.tk1, placeholder: "total")
                    NumberField(label: "TK2 (D)", text: $form.tk2, placeholder: "total")
                    NumberField(label: "Eixo TK2 (°)", text: $form.tkAxis, placeholder: "curvo")
                }
            }
            HStack(spacing: 4) {
                MutedText("Km \(Num.fmt(form.km)) D · ΔK \(Num.fmt(form.deltaK)) D ·")
                Button(form.showTK || form.hasTK ? "ocultar ceratometria total (TK)" : "ceratometria total (TK)") {
                    form.showTK.toggle()
                }
                .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Theme.brand)
                .disabled(form.hasTK)
                HelpButton(topic: .totalKeratometry)
            }
        }
    }
}

// MARK: - 2 · Lentes e alvo

struct LensSection: View {
    @Bindable var model: CalculatorModel
    @State private var showAdvanced = false
    @Environment(\.isCompactWidth) private var compact

    var body: some View {
        SectionCard(title: "2 · Lentes e alvo", trailing: AnyView(methodPicker)) {
            DisclosureGroup(isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    FlowLayout(spacing: 8) {
                        ForEach(BiometryMethod.allCases) { m in
                            NumberField(label: "ΔA \(m.shortLabel)", text: deltaBinding(m)).frame(width: 120)
                        }
                    }
                    MutedText("As constantes do catálogo são as de biometria óptica (IOLcon/ULIB). Com AL de imersão a constante deve cair ≈0,23 (Shammas 2021). A aplanação comprime a córnea e encurta o AL em 0,14–0,28 mm; A óptica = A contato + 3·ΔAL (Hill) dá ≈−0,50 para 0,17 mm. Se tiver a constante otimizada do seu aparelho, use-a aqui.", size: 11.5)
                }
                .padding(.top, 6)
            } label: {
                HStack(spacing: 6) {
                    MutedText("Ajuste da constante A por método · avançado")
                    HelpButton(topic: .biometryMethod)
                }
            }
            .tint(Theme.muted)

            EyePair { eye in
                LensCard(eye: eye, model: model)
            }

            FlowLayout(spacing: 14) {
                Toggle("calcular OD", isOn: $model.od.enabled)
                Toggle("calcular OE", isOn: $model.oe.enabled)
                PillButton(title: "copiar OD → OE") { model.copyODtoOE() }
            }
            #if os(macOS)
            .toggleStyle(.checkbox)
            #else
            .toggleStyle(.button)
            #endif
            .font(.system(size: 12.5)).foregroundStyle(Theme.ink)
        }
    }

    /// No iPhone o rótulo fica em cima e o seletor ocupa a largura toda (numa linha só ele ficava
    /// espremido e o título do método quebrava em várias linhas sobre o texto vizinho).
    private var methodPicker: some View {
        AdaptiveHStack(spacing: 8) {
            HStack(spacing: 4) {
                MutedText("Biometria por", size: 12.5)
                HelpButton(topic: .biometryMethod)
            }
            HStack(spacing: 8) {
                if compact {
                    // O Picker de menu quebra o título longo em várias linhas; no iPhone o rótulo
                    // visível é curto e o menu mostra os títulos completos.
                    Menu {
                        Picker("", selection: $model.method) {
                            ForEach(BiometryMethod.allCases) { Text($0.title).tag($0) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(model.method.compactTitle)
                            Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.semibold))
                        }
                    }
                    .fixedSize()
                } else {
                    Picker("", selection: $model.method) {
                        ForEach(BiometryMethod.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Chip(text: "ΔA " + Num.fmt(model.currentDeltaA, signed: true))
            }
        }
    }

    private func deltaBinding(_ m: BiometryMethod) -> Binding<String> {
        Binding(get: { model.deltaA[m] ?? "" }, set: { model.deltaA[m] = $0 })
    }
}

private struct LensCard: View {
    let eye: Eye
    @Bindable var model: CalculatorModel
    @State private var showOther = false

    var body: some View {
        EyeCard(eye: eye, title: eye.rawValue) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    FieldLabel(text: "LIO")
                    HelpButton(topic: .lensChoice)
                }
                LensPicker(selection: Binding(get: { model[eye].lensID }, set: { model.selectLens($0, for: eye) }),
                           custom: model[eye].custom, onOther: { showOther = true })
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .top, spacing: 8) {
                NumberField(label: "Constante A", text: Binding(get: { model[eye].aConstant }, set: { model[eye].aConstant = $0 }), help: .aConstant)
                NumberField(label: "Alvo (D, equiv. esf.)", text: Binding(get: { model[eye].target }, set: { model.setTarget($0, for: eye) }))
            }
            if let l = model[eye].lens {
                MutedText("\(l.manufacturer) · \(l.type) · A ref \(Num.fmt(l.aConstant)) · disfotopsia \(["baixa", "baixa-mod", "moderada", "alta"][l.dysphotopsia])\(l.curveEstimated ? " · curva estimada" : "")")
            }
        }
        .sheet(isPresented: $showOther) {
            LensChooserSheet(title: "Outra LIO · \(eye.rawValue)", initialCustom: model[eye].custom,
                             onPick: { model.selectLens($0, for: eye) },
                             onCustom: { model.selectCustomLens($0, for: eye) })
        }
    }
}

// MARK: - 3 · Poder da LIO

struct PowerSection: View {
    let model: CalculatorModel

    var body: some View {
        SectionCard(title: "3 · Poder da LIO", trailing: AnyView(HelpButton(topic: .powerSuggestion))) {
            EyePair { eye in
                EyeCard(eye: eye, title: eye.rawValue) {
                    switch model.result(for: eye) {
                    case .disabled:
                        MutedText("desativado")
                    case .incomplete:
                        MutedText("preencha AL, K e constante A")
                    case .plan(let plan):
                        PowerPlanView(plan: plan)
                    }
                }
            }
        }
    }
}

private struct PowerPlanView: View {
    let plan: PowerPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MutedText(header)
            suggestion
            table
            MutedText("Mediana das fórmulas recomendadas \(Num.fmt(plan.medianPower)) D. Residuais calculados por inversão de cada fórmula no poder indicado.", size: 11.5)
            if !plan.warnings.isEmpty { warnings }
        }
    }

    private var header: String {
        let e = plan.eye
        var s = "AL \(Num.fmt(e.axialLength)) mm · Km \(Num.fmt(e.keratometry)) D · ACD \(Num.fmt(e.acd)) · CCT \(Num.fmt(e.centralCornealThickness, 0)) · A \(Num.fmt(plan.aConstant))"
        if plan.deltaA != 0 { s += " → \(Num.fmt(plan.effectiveA)) (\(plan.method.shortLabel))" }
        return s + " · alvo \(Num.fmt(plan.target)) D"
    }

    @Environment(\.isCompactWidth) private var compact

    private var suggestion: some View {
        AdaptiveHStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SUGESTÃO").font(.system(size: 11, weight: .bold)).kerning(0.3)
                Text("\(Num.fmt(plan.chosen.power, 1)) D").font(.system(size: 30, weight: .heavy))
                (Text("residual previsto ") + Text("\(Num.fmt(plan.chosen.residual, signed: true)) D").bold() +
                 Text(plan.reachesTarget ? " · primeira lente que não deixa hipermetropia" : " · nenhum candidato atinge o alvo — confira"))
                    .font(.system(size: 12))
            }
            .foregroundStyle(Theme.okInk)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.okBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.okBorder))

            if let alt = plan.alternative {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ALTERNATIVA").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.muted).kerning(0.3)
                    Text("\(Num.fmt(alt.power, 1)) D").font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink)
                    Text("residual \(Num.fmt(alt.residual, signed: true)) D").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                .padding(12)
                .frame(maxWidth: compact ? .infinity : 150, alignment: .leading)
                .frame(maxHeight: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var shownPowers: [Double] {
        [plan.alternative?.power, plan.chosen.power].compactMap { $0 }
    }

    private var table: some View {
        Group {
            if compact { ScrollView(.horizontal, showsIndicators: false) { grid.fixedSize(horizontal: true, vertical: false) } } else { grid }
        }
    }

    private var grid: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                head("Fórmula", leading: true)
                head("Emetr.")
                head("Alvo")
                ForEach(shownPowers, id: \.self) { p in
                    head("@ \(Num.fmt(p, 1))").background(p == plan.chosen.power ? Theme.okBg : .clear)
                }
            }
            ForEach(plan.rows) { row in
                let bg = row.isRecommended ? Theme.okBg : Color.clear
                GridRow {
                    HStack(spacing: 4) {
                        Text(row.formula.rawValue).font(.system(size: 13, weight: .semibold))
                        if row.isRecommended { Chip(text: "rec") }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 6).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading).background(bg)
                    cell(Num.fmt(row.emmetropiaPower)).background(bg)
                    cell(Num.fmt(row.targetPower), bold: true).background(bg)
                    ForEach(shownPowers, id: \.self) { p in
                        let chosen = p == plan.chosen.power
                        cell(Num.fmt(plan.residual(row.formula, at: p), signed: true), bold: chosen)
                            .background(chosen ? Theme.okBg : bg)
                    }
                }
                Divider().gridCellUnsizedAxes(.horizontal)
            }
        }
        .foregroundStyle(Theme.ink)
    }

    private func head(_ t: String, leading: Bool = false) -> some View {
        Text(t.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: leading ? .leading : .center)
            .padding(.horizontal, 6).padding(.vertical, 6)
    }

    private func cell(_ t: String, bold: Bool = false) -> some View {
        Text(t).font(.system(size: 13, weight: bold ? .bold : .regular))
            .frame(maxWidth: .infinity).padding(.horizontal, 6).padding(.vertical, 6)
    }

    private var warnings: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("⚠ Olho fora da faixa de confiança das fórmulas locais:").bold()
            ForEach(plan.warnings, id: \.self) { Text($0.message) }
            Text("Confira na calculadora ESCRS/Barrett (seção 4) antes de decidir.").italic()
        }
        .font(.system(size: 12.5)).foregroundStyle(Theme.errInk)
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.errBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.errBorder))
    }
}

#Preview {
    NativeCalculatorView()
}

extension BiometryMethod {
    /// Título curto para o rótulo do seletor no iPhone.
    var compactTitle: String {
        switch self {
        case .optical: return "Biometria óptica"
        case .immersion: return "Ultrassom de imersão"
        case .contact: return "Ultrassom de contato"
        }
    }
}

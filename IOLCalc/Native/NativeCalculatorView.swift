import SwiftUI
import IOLCore

/// Seções 1 a 3 da calculadora (biometria, lentes e alvo, poder da LIO) em SwiftUI,
/// calculando com o `IOLCore`. Substitui, aos poucos, a página web embutida.
struct NativeCalculatorView: View {
    @State private var model = CalculatorModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                patientField
                BiometrySection(model: model)
                LensSection(model: model)
                PowerSection(model: model)
                DefocusSection(model: model)
                CompareDrawer(model: model)
                MutedText("Recomendação por AL: olho curto (<22 mm) → Hoffer Q / Haigis / Castrop · médio → todas · longo (>26 mm) → Holladay 1 com ajuste Wang-Koch / T2 / Haigis / Castrop. A sugestão é a mediana das fórmulas recomendadas.", size: 11.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(EdgeInsets(top: 24, leading: 32, bottom: 24, trailing: 32))
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
    }

    private var patientField: some View {
        HStack(spacing: 10) {
            FieldLabel(text: "Paciente")
            TextField("nome do paciente (opcional — sai no relatório)", text: $model.patientName)
                .textFieldStyle(.plain).font(.system(size: 14)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
        }
    }
}

// MARK: - 1 · Biometria

struct BiometrySection: View {
    @Bindable var model: CalculatorModel
    @State private var reader = AIReaderState()

    var body: some View {
        SectionCard(title: "1 · Biometria", trailing: AnyView(
            HStack(spacing: 8) {
                AIReadControls(model: model, reader: reader)
                PillButton(title: "Limpar") { model.clearBiometry(); reader.status = nil }
            }
        )) {
            if let status = reader.status {
                AIReadControls.StatusView(status: status)
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
            }
        }
    }
}

// MARK: - 2 · Lentes e alvo

struct LensSection: View {
    @Bindable var model: CalculatorModel
    @State private var showAdvanced = false

    var body: some View {
        SectionCard(title: "2 · Lentes e alvo", trailing: AnyView(methodPicker)) {
            DisclosureGroup(isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(BiometryMethod.allCases) { m in
                            NumberField(label: "ΔA \(m.shortLabel)", text: deltaBinding(m)).frame(maxWidth: 130)
                        }
                        Spacer()
                    }
                    MutedText("As constantes do catálogo são as de biometria óptica (IOLcon/ULIB). Com AL de imersão a constante deve cair ≈0,23 (Shammas 2021). A aplanação comprime a córnea e encurta o AL em 0,14–0,28 mm; A óptica = A contato + 3·ΔAL (Hill) dá ≈−0,50 para 0,17 mm. Se tiver a constante otimizada do seu aparelho, use-a aqui.", size: 11.5)
                }
                .padding(.top, 6)
            } label: {
                MutedText("Ajuste da constante A por método · avançado")
            }
            .tint(Theme.muted)

            EyePair { eye in
                LensCard(eye: eye, model: model)
            }

            HStack(spacing: 14) {
                Toggle("calcular OD", isOn: $model.od.enabled)
                Toggle("calcular OE", isOn: $model.oe.enabled)
                PillButton(title: "copiar OD → OE") { model.copyODtoOE() }
                Spacer()
            }
            #if os(macOS)
            .toggleStyle(.checkbox)
            #else
            .toggleStyle(.button)
            #endif
            .font(.system(size: 12.5)).foregroundStyle(Theme.ink)
        }
    }

    private var methodPicker: some View {
        HStack(spacing: 8) {
            MutedText("Biometria por", size: 12.5)
            Picker("", selection: $model.method) {
                ForEach(BiometryMethod.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            Chip(text: "ΔA " + Num.fmt(model.currentDeltaA, signed: true))
        }
    }

    private func deltaBinding(_ m: BiometryMethod) -> Binding<String> {
        Binding(get: { model.deltaA[m] ?? "" }, set: { model.deltaA[m] = $0 })
    }
}

private struct LensCard: View {
    let eye: Eye
    @Bindable var model: CalculatorModel

    var body: some View {
        EyeCard(eye: eye, title: eye.rawValue) {
            VStack(alignment: .leading, spacing: 3) {
                FieldLabel(text: "LIO")
                LensPicker(selection: Binding(get: { model[eye].lensID }, set: { model.selectLens($0, for: eye) }))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .top, spacing: 8) {
                NumberField(label: "Constante A", text: Binding(get: { model[eye].aConstant }, set: { model[eye].aConstant = $0 }))
                NumberField(label: "Alvo (D, equiv. esf.)", text: Binding(get: { model[eye].target }, set: { model.setTarget($0, for: eye) }))
            }
            if let l = model[eye].lens {
                MutedText("\(l.manufacturer) · \(l.type) · A ref \(Num.fmt(l.aConstant)) · disfotopsia \(["baixa", "baixa-mod", "moderada", "alta"][l.dysphotopsia])")
            }
        }
    }
}

// MARK: - 3 · Poder da LIO

struct PowerSection: View {
    let model: CalculatorModel

    var body: some View {
        SectionCard(title: "3 · Poder da LIO") {
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

    private var suggestion: some View {
        HStack(spacing: 12) {
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
                .frame(width: 150, alignment: .leading)
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

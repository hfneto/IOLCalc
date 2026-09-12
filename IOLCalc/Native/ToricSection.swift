import SwiftUI
import IOLCore

// MARK: - 7 · Planejamento de LIO tórica

struct ToricSection: View {
    @Bindable var model: CalculatorModel

    var body: some View {
        SectionCard(title: "7 · Planejamento de LIO tórica — ambos os olhos", trailing: AnyView(
            HStack(spacing: 8) {
                PillButton(title: "copiar OD → OE") { model.copyToric(from: .od, to: .oe) }
                PillButton(title: "copiar OE → OD") { model.copyToric(from: .oe, to: .od) }
                Link(destination: URL(string: "https://calc.apacrs.org/toric_calculator20/Toric%20Calculator.aspx")!) {
                    Text("Barrett Toric V2.0 (oficial)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.brand)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line))
                }
            }
        )) {
            MutedText("Some vetorialmente (dupla-ângulo) o astigmatismo corneano, o SIA da incisão e o cilindro da LIO tórica para prever o residual. Arraste o eixo da LIO (verde) e a incisão (laranja) em cada diagrama. Os K são preenchidos automaticamente da Biometria. Apoio ao planejamento — confirme lente e eixo na Barrett Toric oficial antes de indicar.", size: 12.5)
            EyePair { eye in
                ToricCard(eye: eye, model: model)
            }
            MutedText("Convenção: eixos 0–180°. O SIA é somado como vetor cujo meridiano curvo fica 90° do eixo da incisão (a incisão aplana o próprio meridiano). Residual ≈ astigmatismo refracional previsto no plano corneano. A razão de toricidade converte o cilindro da LIO ao plano corneano: calculada pela ELP do olho (SRK/T, com o poder sugerido) quando há biometria; senão, o padrão da plataforma.", size: 11.5)
        }
    }
}

private struct ToricCard: View {
    let eye: Eye
    @Bindable var model: CalculatorModel
    @State private var showAdvanced = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        let plan = model.toricPlan(eye)
        let cornealModel = model.toricModel(eye)
        EyeCard(eye: eye, title: eye.rawValue) {
            if cornealModel != .total {
                MutedText(model.toricSourceLabel(eye), size: 11)
            }
            VStack(alignment: .leading, spacing: 3) {
                FieldLabel(text: "Base do astigmatismo")
                Picker("", selection: Binding(get: { cornealModel }, set: { model[toric: eye].modelOverride = $0 })) {
                    ForEach(CornealAstigmatismModel.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden().fixedSize()
            }
            if let note = cornealModel.note { MutedText(note, size: 11) }
            if cornealModel == .total {
                LazyVGrid(columns: columns, spacing: 8) {
                    NumberField(label: "Astig. total (D)", text: override(\.totalCylinderOverride, model.toricTotalCylinderText(eye)), placeholder: "ex. 1,20")
                    NumberField(label: "Eixo curvo total (°)", text: override(\.totalAxisOverride, model.toricTotalAxisText(eye)))
                }
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    NumberField(label: "K plano (D)", text: override(\.k1Override, model.toricK1Text(eye)))
                    NumberField(label: "K curvo (D)", text: override(\.k2Override, model.toricK2Text(eye)))
                    NumberField(label: "Eixo do K curvo (°)", text: override(\.kAxisOverride, model.toricKAxisText(eye)))
                }
            }
            LazyVGrid(columns: columns, spacing: 8) {
                NumberField(label: "SIA (D)", text: field(\.sia))
                NumberField(label: "Eixo da incisão (°)", text: field(\.siaAxis))
                NumberField(label: "Cilindro LIO (D)", text: field(\.iolCylinder))
                NumberField(label: "Eixo da LIO (°)", text: field(\.iolAxis))
            }
            DisclosureGroup(isExpanded: $showAdvanced) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        FieldLabel(text: "Plataforma")
                        Picker("", selection: Binding(get: { model.toricPlatformID(eye) }, set: { model.setToricPlatform($0, for: eye) })) {
                            ForEach(ToricPlatform.all) { Text($0.name).tag($0.id) }
                        }
                        .labelsHidden().fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            FieldLabel(text: "Razão toricidade")
                            Chip(text: model.toricRatio(eye).source.rawValue)
                        }
                        TextField("", text: Binding(get: { model.toricRatioText(eye) }, set: { model.setToricRatioText($0, for: eye) }))
                            .textFieldStyle(.plain).font(.system(size: 14)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 9).padding(.vertical, 7)
                            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
                            .frame(maxWidth: 120)
                    }
                    Spacer()
                }
                .padding(.top, 6)
            } label: {
                MutedText("Plataforma e razão de toricidade · avançado")
            }
            .tint(Theme.muted)

            HStack(spacing: 8) {
                PillButton(title: "✨ sugerir ideal", primary: true) { model.suggestToric(eye) }
                PillButton(title: "alinhar ao astig.") { model.alignToricToTotal(eye) }
                Spacer()
            }

            ToricDiagram(plan: plan) { target, angle in
                let text = Num.fmt(angle, 0)
                if target == .incision { model[toric: eye].siaAxis = text } else { model[toric: eye].iolAxis = text }
            }
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity, alignment: .leading)

            metrics(plan)
            note(plan)
        }
    }

    private func metrics(_ plan: ToricPlan) -> some View {
        let res = plan.residualMagnitude
        let resBg: Color = res <= 0.5 ? Theme.okBg : (res <= 0.75 ? .white : Theme.errBg)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            MetricCard(label: "Astig. total", value: "\(Num.fmt(plan.totalMagnitude)) D", note: "curvo \(Num.fmt(PowerPlanner.roundHalfUp(plan.totalAxis), 0))°", valueSize: 17)
            MetricCard(label: "LIO no plano corneano", value: "\(Num.fmt(plan.iolAtCornealPlane)) D", note: "\(Num.fmt(plan.input.iolCylinder))÷\(Num.fmt(plan.input.ratio))", valueSize: 17)
            MetricCard(label: "Residual previsto", value: "\(Num.fmt(res)) D", note: "eixo \(Num.fmt(PowerPlanner.roundHalfUp(plan.residualAxis), 0))°", background: resBg, valueSize: 17)
            MetricCard(label: "Residual se perfeito", value: "\(Num.fmt(plan.residualIfAligned)) D", note: "@ \(Num.fmt(PowerPlanner.roundHalfUp(plan.totalAxis), 0))°", valueSize: 17)
        }
    }

    private func note(_ plan: ToricPlan) -> some View {
        var s = "Desalinhamento LIO×astig: \(Num.fmt(plan.misalignment, 0))°"
        if plan.misalignment >= 1 { s += " (~\(plan.lostCorrectionPercent)% da correção perdida)" }
        if plan.input.iolCylinder == 0 { s += ". Cilindro 0 — toque em “sugerir ideal”." }
        if plan.belowToricThreshold { s += " Astig. total < 0,75 D — normalmente não se indica tórica." }
        return MutedText(s)
    }

    /// Campo que segue a biometria até ser editado.
    private func override(_ path: WritableKeyPath<ToricForm, String?>, _ effective: String) -> Binding<String> {
        Binding(get: { effective }, set: { model[toric: eye][keyPath: path] = $0 })
    }

    private func field(_ path: WritableKeyPath<ToricForm, String>) -> Binding<String> {
        Binding(get: { model[toric: eye][keyPath: path] }, set: { model[toric: eye][keyPath: path] = $0 })
    }
}

// MARK: - Diagrama interativo

/// Diagrama polar do olho: astigmatismo total (roxo), eixo da LIO (verde, arrastável pelas
/// alças), residual (vermelho) e incisão (laranja, arrastável). Porte do `drawToric` da web.
struct ToricDiagram: View {
    enum DragTarget { case incision, iol }

    let plan: ToricPlan
    /// Chamado durante o arrasto com o ângulo (0–180°) já arredondado.
    let onDrag: (DragTarget, Double) -> Void

    @State private var dragging: DragTarget?

    static let purple = Color(hex: 0x7c3aed)
    static let green = Color(hex: 0x059669)
    static let red = Color(hex: 0xdc2626)
    static let orange = Color(hex: 0xea580c)

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Canvas { ctx, size in
                draw(&ctx, size: size)
            }
            .contentShape(Rectangle())
            .gesture(gesture(side: side))
        }
        .aspectRatio(1, contentMode: .fit)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
        .accessibilityLabel("Diagrama do astigmatismo")
    }

    /// O alvo (incisão ou eixo da LIO) é decidido pelo ponto inicial do toque, como na web.
    private func gesture(side: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                if dragging == nil { dragging = nearIncision(v.startLocation, side: side) ? .incision : .iol }
                guard let dragging else { return }
                onDrag(dragging, angle(of: v.location, side: side))
            }
            .onEnded { _ in dragging = nil }
    }

    private func angle(of p: CGPoint, side: CGFloat) -> Double {
        let c = side / 2
        var a = atan2(-(p.y - c), p.x - c) * 180 / .pi
        a = (a.truncatingRemainder(dividingBy: 180) + 180).truncatingRemainder(dividingBy: 180)
        return PowerPlanner.roundHalfUp(a)
    }

    private func nearIncision(_ p: CGPoint, side: CGFloat) -> Bool {
        let c = side / 2, r = side * 0.40, k = side / 440
        let ia = plan.input.siaAxis * .pi / 180
        let ix = c + cos(ia) * r, iy = c - sin(ia) * r
        return hypot(p.x - ix, p.y - iy) < 24 * k
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let w = min(size.width, size.height)
        let k = w / 440
        let cx = w / 2, cy = w / 2, r = w * 0.40
        let d2r = Double.pi / 180

        ctx.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)), with: .color(Color(hex: 0xcbd5e1)), lineWidth: 1.5 * k)
        for d in stride(from: 0, to: 180, by: 30) {
            let a = Double(d) * d2r
            var p = Path()
            p.move(to: CGPoint(x: cx + cos(a) * r, y: cy - sin(a) * r))
            p.addLine(to: CGPoint(x: cx - cos(a) * r, y: cy + sin(a) * r))
            ctx.stroke(p, with: .color(Color(hex: 0xeef2f7)), lineWidth: 1 * k)
            let label = ctx.resolve(Text("\(d)°").font(.system(size: 10 * k)).foregroundColor(Color(hex: 0x94a3b8)))
            ctx.draw(label, at: CGPoint(x: cx + cos(a) * (r + 15 * k), y: cy - sin(a) * (r + 15 * k)), anchor: .center)
        }

        func line(_ axis: Double, _ color: Color, _ width: Double, _ len: Double) {
            let a = axis * d2r, l = r * len
            var p = Path()
            p.move(to: CGPoint(x: cx - cos(a) * l, y: cy + sin(a) * l))
            p.addLine(to: CGPoint(x: cx + cos(a) * l, y: cy - sin(a) * l))
            ctx.stroke(p, with: .color(color), lineWidth: width * k)
        }
        line(plan.totalAxis, Self.purple, 6, 0.96)
        line(plan.input.iolAxis, Self.green, 3.5, 0.82)
        if plan.residualMagnitude > 0.02 {
            line(plan.residualAxis, Self.red, 2, min(1, plan.residualMagnitude / max(0.5, plan.totalMagnitude)) * 0.7)
        }

        // incisão
        let ia = plan.input.siaAxis * d2r
        let ix = cx + cos(ia) * r, iy = cy - sin(ia) * r
        ctx.fill(Path(ellipseIn: CGRect(x: ix - 8 * k, y: iy - 8 * k, width: 16 * k, height: 16 * k)), with: .color(Self.orange))
        ctx.draw(ctx.resolve(Text("✚").font(.system(size: 9 * k)).foregroundColor(.white)), at: CGPoint(x: ix, y: iy), anchor: .center)

        // alças do eixo da LIO
        let ga = plan.input.iolAxis * d2r
        for (hx, hy) in [(cx + cos(ga) * r * 0.82, cy - sin(ga) * r * 0.82), (cx - cos(ga) * r * 0.82, cy + sin(ga) * r * 0.82)] {
            let rect = CGRect(x: hx - 6.5 * k, y: hy - 6.5 * k, width: 13 * k, height: 13 * k)
            ctx.fill(Path(ellipseIn: rect), with: .color(Self.green))
            ctx.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 2 * k)
        }

        // legenda
        func legend(_ t: String, _ color: Color, _ x: Double, _ y: Double) {
            ctx.draw(ctx.resolve(Text(t).font(.system(size: 11 * k)).foregroundColor(color)), at: CGPoint(x: x, y: y), anchor: .bottomLeading)
        }
        legend("■ astig. total", Self.purple, 10 * k, w - 34 * k)
        legend("■ eixo LIO", Self.green, 10 * k, w - 18 * k)
        legend("✚ incisão", Self.orange, w - 140 * k, w - 34 * k)
        legend("■ residual", Self.red, w - 140 * k, w - 18 * k)
    }
}

import SwiftUI
import IOLCore

// MARK: - 6 · Simulação visual (cenas fotográficas)

struct SimulationSection: View {
    @Bindable var model: CalculatorModel

    private var anyEye: Bool { model.eyeActive(.od) || model.eyeActive(.oe) }

    var body: some View {
        SectionCard(title: "6 · Simulação visual") {
            MutedText("Duas cenas reais vistas do banco do motorista, cada uma com as três distâncias: o celular na mão (40 cm), o painel (75 cm) e a rua pelo para-brisa (longe). Cada camada é desfocada pela AV binocular prevista naquela distância (lentes + residual + astigmatismo, se ligado). À noite entram a penalidade mesópica e os halos nas luzes.", size: 12.5)
            sceneBlock(.day)
            sceneBlock(.night)
            if anyEye {
                let dys = model.simulationDysphotopsia()
                (Text("À noite a combinação escolhida tende a disfotopsia ") + Text(VisualSimulation.dysphotopsiaLabels[dys]).bold()
                 + Text(" (classe das lentes). Use os botões da cena noturna para mostrar ao paciente a variação individual (\(VisualSimulation.haloModeLabels[model.simulationHaloMode])): alguns notam quase nada, a maioria nota halos ao dirigir, poucos têm queixa importante."))
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            MutedText("Calibração: a AV prevista (logMAR) no defocus de cada distância vira um desfoque gaussiano com σ = 0,6·(MAR − 1) minutos de arco (MAR = 10^logMAR), a 2 px por minuto de arco. À noite soma-se +0,08 logMAR (mesópico); nas luzes, halos, anéis e starburst com intensidade pela classe da lente (difrativas = mais). As ópticas difrativas perdem ≈0,1–0,2 log de sensibilidade ao contraste, aplicado como redução de contraste. Fotos: Tim Foster, M. R. e personalgraphic.com (Unsplash).", size: 11.5)
        }
    }

    private func sceneBlock(_ scene: SimulationScene) -> some View {
        let acuities = VisualSimulation.distances.map { model.simulationAcuity($0, night: scene.night) }
        return VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { header(scene, acuities); Spacer(minLength: 0); if scene.night { haloPicker } }
                VStack(alignment: .leading, spacing: 6) { header(scene, acuities); if scene.night { haloPicker } }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Theme.soft)
            SimulationSceneView(scene: scene, acuities: acuities, haloMode: model.simulationHaloMode,
                                dysphotopsia: model.simulationDysphotopsia(), astigmatism: model.simulationAstigmatism())
                .aspectRatio(VisualSimulation.sceneWidth / VisualSimulation.sceneHeight, contentMode: .fit)
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
    }

    private func header(_ scene: SimulationScene, _ acuities: [Double?]) -> some View {
        HStack(spacing: 10) {
            Text(scene.night ? "🌙 Noite" : "☀ Dia").font(.system(size: 12.5, weight: .bold)).foregroundStyle(Theme.ink)
            ForEach(Array(VisualSimulation.distances.enumerated()), id: \.offset) { i, d in
                HStack(spacing: 4) {
                    Text(d.label).font(.system(size: 11.5)).foregroundStyle(Theme.muted)
                    Text(acuities[i].map { DefocusModel.snellen(fromLogMAR: $0) } ?? "—")
                        .font(.system(size: 12.5, weight: .heavy))
                        .foregroundStyle(acuities[i].map { $0 <= 0.2 ? ToricDiagram.green : ($0 <= 0.4 ? Theme.warn : Theme.od) } ?? Theme.muted)
                }
            }
        }
        .fixedSize()
    }

    private var haloPicker: some View {
        Picker("", selection: $model.simulationHaloMode) {
            Text("melhor caso").tag(0)
            Text("mais comum").tag(1)
            Text("pior caso").tag(2)
        }
        .pickerStyle(.segmented).labelsHidden().fixedSize()
    }
}

// MARK: - Cena

/// Uma cena fotográfica: foto do banco do motorista (painel a ≈75 cm), polígonos do que se vê pelo
/// vidro (longe) e as fontes de luz para os halos noturnos. Coordenadas normalizadas (0–1, y para
/// baixo) sobre a foto 14:9, que é desenhada esticada no quadro de 1120 × 720.
struct SimulationScene {
    struct Light {
        let x: Double, y: Double, radius: Double, strength: Double
        let color: Color
    }

    let imageName: String
    let night: Bool
    let farPolygons: [[CGPoint]]
    let lights: [Light]

    static let day = SimulationScene(
        imageName: "sim-day", night: false,
        farPolygons: [
            [(0.16, 0.0), (0.76, 0.0), (0.83, 0.20), (0.86, 0.27), (1.0, 0.31), (1.0, 0.56), (0.72, 0.585), (0.55, 0.59), (0.31, 0.60),
             (0.27, 0.50), (0.21, 0.30), (0.21, 0.12)].map { CGPoint(x: $0.0, y: $0.1) },
            [(0.0, 0.42), (0.06, 0.36), (0.13, 0.40), (0.13, 0.53), (0.0, 0.56)].map { CGPoint(x: $0.0, y: $0.1) },
        ],
        lights: [])

    static let night = SimulationScene(
        imageName: "sim-night", night: true,
        farPolygons: [
            [(0.13, 0.0), (1.0, 0.0), (1.0, 0.53), (0.78, 0.56), (0.55, 0.53), (0.30, 0.51), (0.20, 0.47), (0.13, 0.42)].map { CGPoint(x: $0.0, y: $0.1) },
        ],
        lights: [
            Light(x: 0.473, y: 0.260, radius: 0.012, strength: 0.9, color: Color(red: 1, green: 0.85, blue: 0.55)),
            Light(x: 0.540, y: 0.300, radius: 0.006, strength: 0.8, color: Color(red: 1, green: 0.95, blue: 0.8)),
            Light(x: 0.575, y: 0.292, radius: 0.006, strength: 0.8, color: Color(red: 1, green: 0.95, blue: 0.8)),
            Light(x: 0.688, y: 0.343, radius: 0.005, strength: 0.9, color: Color(red: 1, green: 0.3, blue: 0.25)),
            Light(x: 0.704, y: 0.343, radius: 0.005, strength: 0.9, color: Color(red: 1, green: 0.3, blue: 0.25)),
        ])

    /// Caminho dos polígonos "longe" em px de cena.
    func farPath(width W: Double, height H: Double) -> Path {
        var p = Path()
        for poly in farPolygons {
            guard let f = poly.first else { continue }
            p.move(to: CGPoint(x: f.x * W, y: f.y * H))
            for pt in poly.dropFirst() { p.addLine(to: CGPoint(x: pt.x * W, y: pt.y * H)) }
            p.closeSubpath()
        }
        return p
    }
}

/// Desenha uma cena com as três camadas desfocadas, o celular com a mensagem, contraste, brilho e
/// halos noturnos e o arrasto do astigmatismo.
struct SimulationSceneView: View {
    let scene: SimulationScene
    /// AV (logMAR) nas distâncias de `VisualSimulation.distances` (perto, painel, longe); `nil` sem olho ativo.
    let acuities: [Double?]
    let haloMode: Int
    let dysphotopsia: Int
    let astigmatism: (cylinder: Double, axis: Double)?

    private let W = VisualSimulation.sceneWidth
    private let H = VisualSimulation.sceneHeight
    /// Onde a mão com o celular entra (px de cena) — a foto tem 900 × 1240.
    private let phoneRect = CGRect(x: 745, y: 292, width: 345, height: 475)
    /// Tela do celular, normalizada à foto da mão (com cantos arredondados).
    private let screenRect = CGRect(x: 0.37, y: 0.09, width: 0.55, height: 0.845)

    var body: some View {
        Canvas(rendersAsynchronously: true) { ctx, size in
            render(&ctx, size: size)
        }
    }

    private func render(_ ctx: inout GraphicsContext, size: CGSize) {
        let s = size.width / W
        ctx.clip(to: Path(CGRect(origin: .zero, size: size)))
        let photo = ctx.resolve(Image(scene.imageName))
        let hand = ctx.resolve(Image("sim-hand"))
        guard acuities.count == 3, let near = acuities[0], let mid = acuities[1], let far = acuities[2] else {
            // sem olho ativo: cena nítida, apagada, com aviso
            ctx.drawLayer { l in l.scaleBy(x: s, y: s); l.draw(photo, in: CGRect(x: 0, y: 0, width: W, height: H)) }
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.55)))
            ctx.draw(ctx.resolve(Text("Selecione a LIO (seção 2)").font(.system(size: 44 * s, weight: .semibold)).foregroundColor(.white)),
                     at: CGPoint(x: size.width / 2, y: size.height / 2), anchor: .center)
            return
        }
        let k = VisualSimulation.sceneBlurPixelsPerArcMinute
        let sigma = (near: VisualSimulation.blurSigma(logMAR: near, pixelsPerArcMinute: k) * s,
                     mid: VisualSimulation.blurSigma(logMAR: mid, pixelsPerArcMinute: k) * s,
                     far: VisualSimulation.blurSigma(logMAR: far, pixelsPerArcMinute: k) * s)

        // arrasto direcional do astigmatismo: várias cópias deslocadas ao longo do eixo
        // arrasto na ampliação da cena: 1 D ≈ 5′ de arco (metade da regra dos quadros antigos, para
        // ficar proporcional ao desfoque gaussiano da penalidade de AV do cilindro)
        let smear = (astigmatism.map { VisualSimulation.directionalBlur(cylinder: $0.cylinder) } ?? 0) * (k / VisualSimulation.pixelsPerArcMinute) * 0.5
        if let astigmatism, astigmatism.cylinder > 0.1, smear >= 0.5 {
            // média exata das cópias: soma aditiva (1/n cada) sobre preto — com "over" a cobertura
            // ficaria em 1 − (1 − 1/n)^n ≈ 66 % e o fundo branco vazaria como uma névoa.
            let n = 8
            let rad = astigmatism.axis * .pi / 180
            let dx = cos(rad), dy = -sin(rad)
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            var acc = ctx
            acc.blendMode = .plusLighter   // vale para a composição de cada cópia no acumulador…
            acc.opacity = 1 / Double(n)
            for i in 0..<n {
                let t = (Double(i) / Double(n - 1) - 0.5) * 2 * smear
                acc.drawLayer { l in
                    l.blendMode = .normal       // …mas dentro da cópia o celular cobre o painel normalmente
                    l.opacity = 1
                    l.translateBy(x: dx * t * s, y: dy * t * s)
                    composite(&l, s: s, photo: photo, hand: hand, sigma: sigma)
                }
            }
        } else {
            composite(&ctx, s: s, photo: photo, hand: hand, sigma: sigma)
        }

        // perda de contraste das ópticas difrativas
        let cf = VisualSimulation.contrast(dysphotopsia: dysphotopsia, night: scene.night)
        if cf < 1 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.5, green: 0.5, blue: 0.5).opacity(1 - cf)))
        }
        if scene.night { drawNightLights(&ctx, s: s) }
    }

    /// Painel (foto inteira) desfocado a 75 cm → vidro (polígonos) desfocado ao longe → celular a 40 cm.
    private func composite(_ ctx: inout GraphicsContext, s: Double, photo: GraphicsContext.ResolvedImage, hand: GraphicsContext.ResolvedImage,
                           sigma: (near: Double, mid: Double, far: Double)) {
        let full = CGRect(x: 0, y: 0, width: W, height: H)
        ctx.drawLayer { l in
            if sigma.mid > 0.3 { l.addFilter(.blur(radius: sigma.mid)) }
            l.scaleBy(x: s, y: s)
            l.draw(photo, in: full)
        }
        var farCtx = ctx
        farCtx.clip(to: scene.farPath(width: W * s, height: H * s))
        farCtx.drawLayer { l in
            if sigma.far > 0.3 { l.addFilter(.blur(radius: sigma.far)) }
            l.scaleBy(x: s, y: s)
            l.draw(photo, in: full)
        }
        ctx.drawLayer { l in
            if sigma.near > 0.3 { l.addFilter(.blur(radius: sigma.near)) }
            l.scaleBy(x: s, y: s)
            l.draw(hand, in: phoneRect)
            drawPhoneScreen(&l)
        }
    }

    /// Conversa de mensagens na tela do celular (texto de 15 pt a 40 cm ≈ 8 % da largura da tela).
    private func drawPhoneScreen(_ c: inout GraphicsContext) {
        let r = CGRect(x: phoneRect.minX + screenRect.minX * phoneRect.width, y: phoneRect.minY + screenRect.minY * phoneRect.height,
                       width: screenRect.width * phoneRect.width, height: screenRect.height * phoneRect.height)
        let night = scene.night
        c.clip(to: Path(roundedRect: r, cornerRadius: r.width * 0.11))
        c.fill(Path(r), with: .color(night ? Color(hex: 0x0b141a) : Color(hex: 0xe5ddd5)))
        let fs = r.width * 0.083
        // barra do contato
        let bar = CGRect(x: r.minX, y: r.minY, width: r.width, height: fs * 2.6)
        c.fill(Path(bar), with: .color(night ? Color(hex: 0x1f2c34) : Color(hex: 0x075e54)))
        let av = CGRect(x: r.minX + fs * 0.6, y: bar.minY + fs * 1.15, width: fs * 1.15, height: fs * 1.15)
        c.fill(Path(ellipseIn: av), with: .color(Color(hex: 0x94a3b8)))
        c.draw(c.resolve(Text("Dr. Hallim").font(.system(size: fs * 0.9, weight: .semibold)).foregroundColor(.white)),
               at: CGPoint(x: av.maxX + fs * 0.5, y: av.midY), anchor: .leading)
        // balões
        func bubble(_ lines: [String], y: Double, mine: Bool) -> Double {
            let texts = lines.map { c.resolve(Text($0).font(.system(size: fs)).foregroundColor(night ? Color(hex: 0xe9edef) : Color(hex: 0x111b21))) }
            let w = (texts.map { $0.measure(in: CGSize(width: 10_000, height: 10_000)).width }.max() ?? 0) + fs * 1.2
            let lh = fs * 1.3, h = lh * Double(lines.count) + fs * 0.9
            let x = mine ? r.maxX - fs * 0.5 - w : r.minX + fs * 0.5
            let bg: Color = mine ? (night ? Color(hex: 0x005c4b) : Color(hex: 0xdcf8c6)) : (night ? Color(hex: 0x202c33) : .white)
            c.fill(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: fs * 0.5), with: .color(bg))
            for (i, t) in texts.enumerated() { c.draw(t, at: CGPoint(x: x + fs * 0.6, y: y + fs * 0.45 + lh * Double(i)), anchor: .topLeading) }
            return y + h + fs * 0.6
        }
        var y = bar.maxY + fs * 0.8
        y = bubble(["Bom dia! Sua cirurgia", "ficou para quinta, 8h30."], y: y, mine: false)
        y = bubble(["Chegar em jejum", "de 8 horas."], y: y, mine: false)
        y = bubble(["Combinado, obrigada!"], y: y, mine: true)
        _ = y
        c.draw(c.resolve(Text("08:12").font(.system(size: fs * 0.7)).foregroundColor(night ? Color(hex: 0x8696a0) : Color(hex: 0x667781))),
               at: CGPoint(x: r.maxX - fs * 0.6, y: r.maxY - fs * 0.5), anchor: .bottomTrailing)
    }

    /// Halo, anéis difrativos e starburst nas luzes conhecidas da cena.
    private func drawNightLights(_ ctx: inout GraphicsContext, s: Double) {
        let I = VisualSimulation.haloIntensity(dysphotopsia: dysphotopsia, mode: haloMode)
        guard I >= 0.02 else { return }
        // anéis (≈0,4–0,65° de raio) e starburst na ampliação da cena: bem menores que nos quadros antigos
        let pxa = 0.8
        for (idx, L) in scene.lights.enumerated() {
            let cx = L.x * W, cy = L.y * H, r = L.radius * W
            let col = L.color, sz = min(L.strength, 1.35)
            let outer = r + 14 + 40 * I * sz
            var c = ctx
            c.scaleBy(x: s, y: s)
            let center = CGPoint(x: cx, y: cy)
            c.fill(Path(ellipseIn: CGRect(x: cx - outer, y: cy - outer, width: 2 * outer, height: 2 * outer)),
                   with: .radialGradient(Gradient(colors: [col.opacity(min(0.55, 0.3 * I * sz)), col.opacity(0)]), center: center, startRadius: r, endRadius: outer))
            guard dysphotopsia >= 1 else { continue }
            let rings: [Double] = dysphotopsia >= 3 ? [24 * pxa, 39 * pxa] : [30 * pxa]
            for R in rings {
                let a = min(0.55, (dysphotopsia >= 3 ? 0.22 : 0.13) * I * sz)
                let rr = R * (1 + 0.08 * I)
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 3 * s))
                    l.scaleBy(x: s, y: s)
                    l.stroke(Path(ellipseIn: CGRect(x: cx - rr, y: cy - rr, width: 2 * rr, height: 2 * rr)), with: .color(col.opacity(a)), lineWidth: 2.5)
                }
            }
            let n = 16
            let base = (10 + 35 * I * sz) * pxa * 0.6
            let phase = (Double(idx) * 2.399).truncatingRemainder(dividingBy: 6.283)
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 1.0 * s))
                l.scaleBy(x: s, y: s)
                for k in 0..<n {
                    let ang = Double(k) * .pi * 2 / Double(n) + phase
                    let len = base * (0.6 + 0.55 * abs(sin(Double(k) * 1.7 + Double(idx))))
                    let end = CGPoint(x: cx + cos(ang) * len, y: cy + sin(ang) * len)
                    var p = Path()
                    p.move(to: center)
                    p.addLine(to: end)
                    l.stroke(p, with: .linearGradient(Gradient(colors: [col.opacity(min(0.6, 0.35 * I * sz)), col.opacity(0)]), startPoint: center, endPoint: end), lineWidth: 1.6)
                }
            }
        }
    }
}

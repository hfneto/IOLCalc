import SwiftUI
import IOLCore

// MARK: - 6 · Simulação visual (cenas fotográficas)

struct SimulationSection: View {
    @Bindable var model: CalculatorModel

    private var anyEye: Bool { model.eyeActive(.od) || model.eyeActive(.oe) }

    var body: some View {
        SectionCard(title: "6 · Simulação visual") {
            MutedText("Duas cenas reais com as três distâncias: de dia, numa cafeteria (celular na mão a 40 cm, e-mail no notebook a 66 cm, a rua e as lojas pela janela); à noite, dirigindo (celular na mão, GPS do carro a 66 cm, o carro à frente com a placa, faróis e luzes da cidade). Cada camada é desfocada pela AV binocular prevista naquela distância (lentes + residual + astigmatismo, se ligado). À noite entram a penalidade mesópica e os halos nas luzes.", size: 12.5)
            sceneBlock(.day)
            sceneBlock(.night)
            if anyEye {
                let dys = model.simulationDysphotopsia()
                (Text("À noite a combinação escolhida tende a disfotopsia ") + Text(VisualSimulation.dysphotopsiaLabels[dys]).bold()
                 + Text(" (classe das lentes). Use os botões da cena noturna para mostrar ao paciente a variação individual (\(VisualSimulation.haloModeLabels[model.simulationHaloMode])): alguns notam quase nada, a maioria nota halos ao dirigir, poucos têm queixa importante."))
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            MutedText("Calibração: a AV prevista (logMAR) no defocus de cada distância vira um desfoque gaussiano com σ = 0,6·(MAR − 1) minutos de arco (MAR = 10^logMAR), a 2 px por minuto de arco. À noite soma-se +0,08 logMAR (mesópico); nas luzes, halos, anéis e starburst com intensidade pela classe da lente (difrativas = mais). As ópticas difrativas perdem ≈0,1–0,2 log de sensibilidade ao contraste, aplicado como redução de contraste. Fotos: Blake Wisz (cafeteria), Selcuk Sarikoz (noite) e personalgraphic.com (mão), licença Unsplash.", size: 11.5)
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
                    Text(d.id == "mid" ? (scene.night ? "GPS · 66 cm" : "Notebook · 66 cm") : d.label).font(.system(size: 11.5)).foregroundStyle(Theme.muted)
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

    /// Tela a 66 cm desenhada sobre a foto: e-mail no notebook (quadrilátero, transformação afim
    /// pelos cantos superior-esquerdo, superior-direito e inferior-esquerdo) ou GPS do carro (retângulo).
    enum MidScreen {
        case laptop(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint)
        case navigation(CGRect)
    }

    let imageName: String
    let night: Bool
    let farPolygons: [[CGPoint]]
    let lights: [Light]
    /// Onde a mão com o celular entra (px de cena 1120 × 720; a foto da mão tem 900 × 1240).
    let phoneRect: CGRect
    let midScreen: MidScreen

    static let day = SimulationScene(
        imageName: "sim-day", night: false,
        farPolygons: [
            [(0.17, 0.0), (1.0, 0.0), (1.0, 0.60), (0.92, 0.62), (0.62, 0.63), (0.40, 0.62), (0.20, 0.60), (0.17, 0.55)].map { CGPoint(x: $0.0, y: $0.1) },
        ],
        lights: [],
        phoneRect: CGRect(x: 30, y: 300, width: 330, height: 455),
        midScreen: .laptop(topLeft: CGPoint(x: 0.628, y: 0.556), topRight: CGPoint(x: 0.914, y: 0.583), bottomLeft: CGPoint(x: 0.622, y: 0.806)))

    static let night = SimulationScene(
        imageName: "sim-night", night: true,
        farPolygons: [
            [(0.32, 0.22), (0.60, 0.17), (0.99, 0.17), (1.0, 0.62), (0.62, 0.62), (0.45, 0.60), (0.33, 0.50), (0.30, 0.35)].map { CGPoint(x: $0.0, y: $0.1) },
        ],
        lights: [
            // faróis dos carros que vêm de frente
            Light(x: 0.458, y: 0.568, radius: 0.017, strength: 1.2, color: Color(red: 1, green: 0.97, blue: 0.9)),
            Light(x: 0.506, y: 0.541, radius: 0.016, strength: 1.1, color: Color(red: 1, green: 0.97, blue: 0.9)),
            Light(x: 0.411, y: 0.559, radius: 0.013, strength: 1.0, color: Color(red: 1, green: 0.97, blue: 0.9)),
            Light(x: 0.516, y: 0.487, radius: 0.011, strength: 0.8, color: Color(red: 1, green: 0.97, blue: 0.9)),
            Light(x: 0.532, y: 0.523, radius: 0.010, strength: 0.8, color: Color(red: 1, green: 0.97, blue: 0.9)),
            // carro à frente: lanternas e luz de freio
            Light(x: 0.654, y: 0.557, radius: 0.016, strength: 1.0, color: Color(red: 1, green: 0.85, blue: 0.5)),
            Light(x: 0.922, y: 0.558, radius: 0.010, strength: 0.9, color: Color(red: 1, green: 0.8, blue: 0.5)),
            Light(x: 0.780, y: 0.439, radius: 0.012, strength: 0.9, color: Color(red: 1, green: 0.35, blue: 0.25)),
        ],
        phoneRect: CGRect(x: 840, y: 348, width: 270, height: 372),
        midScreen: .navigation(CGRect(x: 0.60, y: 0.74, width: 0.145, height: 0.13)))

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
    private var phoneRect: CGRect { scene.phoneRect }
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
            if sigma.mid > 0.3 { l.addFilter(.blur(radius: sigma.mid)) }
            l.scaleBy(x: s, y: s)
            drawMidScreen(&l)
        }
        ctx.drawLayer { l in
            if sigma.near > 0.3 { l.addFilter(.blur(radius: sigma.near)) }
            l.scaleBy(x: s, y: s)
            l.draw(hand, in: phoneRect)
            drawPhoneScreen(&l)
        }
    }

    /// Tela a 66 cm: e-mail no notebook (dia) ou GPS no painel (noite). Texto maior que o físico
    /// (as fotos têm campo largo, o real seria ilegível) mas em proporção entre as distâncias.
    private func drawMidScreen(_ c: inout GraphicsContext) {
        switch scene.midScreen {
        case .laptop(let tl, let tr, let bl):
            // transformação afim: unidade → quadrilátero da tela (px de cena)
            let o = CGPoint(x: tl.x * W, y: tl.y * H)
            let ax = CGPoint(x: (tr.x - tl.x) * W, y: (tr.y - tl.y) * H)
            let ay = CGPoint(x: (bl.x - tl.x) * W, y: (bl.y - tl.y) * H)
            let sw = hypot(ax.x, ax.y), sh = hypot(ay.x, ay.y)
            c.concatenate(CGAffineTransform(a: ax.x / sw, b: ax.y / sw, c: ay.x / sh, d: ay.y / sh, tx: o.x, ty: o.y))
            let r = CGRect(x: 0, y: 0, width: sw, height: sh)
            c.clip(to: Path(r))
            c.fill(Path(r), with: .color(Color(hex: 0xf3f4f6)))
            let fs = sw * 0.045
            // barra de janela + cabeçalho do e-mail
            c.fill(Path(CGRect(x: 0, y: 0, width: sw, height: fs * 1.6)), with: .color(Color(hex: 0xe5e7eb)))
            for (i, col) in [Color(hex: 0xff5f57), Color(hex: 0xfebc2e), Color(hex: 0x28c840)].enumerated() {
                c.fill(Path(ellipseIn: CGRect(x: fs * (0.6 + Double(i) * 0.9), y: fs * 0.5, width: fs * 0.6, height: fs * 0.6)), with: .color(col))
            }
            let body = CGRect(x: fs * 0.8, y: fs * 2.3, width: sw - fs * 1.6, height: sh - fs * 3)
            c.fill(Path(roundedRect: body, cornerRadius: fs * 0.4), with: .color(.white))
            var y = body.minY + fs * 0.7
            func line(_ t: String, _ size: Double, weight: Font.Weight = .regular, color: Color = Color(hex: 0x1f2937)) {
                c.draw(c.resolve(Text(t).font(.system(size: size, weight: weight)).foregroundColor(color)), at: CGPoint(x: body.minX + fs * 0.8, y: y), anchor: .topLeading)
                y += size * 1.45
            }
            line("Confirmação da cirurgia", fs * 1.25, weight: .bold)
            line("Clínica Dr. Hallim · para: Maria", fs * 0.85, color: Color(hex: 0x6b7280))
            y += fs * 0.5
            line("Prezada Maria,", fs)
            line("confirmamos a sua cirurgia para", fs)
            line("quinta, dia 24, às 7h. Chegar em", fs)
            line("jejum de 8 horas.", fs)
            y += fs * 0.4
            line("Atenciosamente,", fs)
            line("Equipe Dr. Hallim", fs, weight: .semibold)
        case .navigation(let nr):
            let r = CGRect(x: nr.minX * W, y: nr.minY * H, width: nr.width * W, height: nr.height * H)
            c.clip(to: Path(roundedRect: r, cornerRadius: r.width * 0.03))
            // mapa escuro com a rota
            c.fill(Path(r), with: .color(Color(hex: 0x1f2937)))
            var road = Path()
            road.move(to: CGPoint(x: r.minX + r.width * 0.55, y: r.maxY)); road.addLine(to: CGPoint(x: r.minX + r.width * 0.55, y: r.minY + r.height * 0.55)); road.addLine(to: CGPoint(x: r.minX + r.width * 0.2, y: r.minY + r.height * 0.55))
            c.stroke(road, with: .color(Color(hex: 0x374151)), lineWidth: r.width * 0.09)
            c.stroke(road, with: .color(Color(hex: 0x3b82f6)), style: StrokeStyle(lineWidth: r.width * 0.045, lineCap: .round, lineJoin: .round))
            var minor = Path()
            minor.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.8)); minor.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.8))
            minor.move(to: CGPoint(x: r.minX + r.width * 0.8, y: r.minY)); minor.addLine(to: CGPoint(x: r.minX + r.width * 0.8, y: r.maxY))
            c.stroke(minor, with: .color(Color(hex: 0x374151)), lineWidth: r.width * 0.04)
            // painel de instrução
            let bh = r.height * 0.36
            c.fill(Path(CGRect(x: r.minX, y: r.minY, width: r.width, height: bh)), with: .color(Color(hex: 0x15803d)))
            let fs = r.width * 0.11
            let ax = r.minX + fs * 0.4, ay = r.minY + bh / 2
            var arrow = Path()
            arrow.move(to: CGPoint(x: ax + fs * 0.75, y: ay + fs * 0.55)); arrow.addLine(to: CGPoint(x: ax + fs * 0.75, y: ay - fs * 0.15)); arrow.addLine(to: CGPoint(x: ax + fs * 0.1, y: ay - fs * 0.15))
            arrow.move(to: CGPoint(x: ax + fs * 0.42, y: ay - fs * 0.5)); arrow.addLine(to: CGPoint(x: ax + fs * 0.05, y: ay - fs * 0.15)); arrow.addLine(to: CGPoint(x: ax + fs * 0.42, y: ay + fs * 0.2))
            c.stroke(arrow, with: .color(.white), style: StrokeStyle(lineWidth: fs * 0.16, lineCap: .round, lineJoin: .round))
            c.draw(c.resolve(Text("300 m").font(.system(size: fs, weight: .bold)).foregroundColor(.white)), at: CGPoint(x: ax + fs * 1.1, y: ay - fs * 0.25), anchor: .leading)
            c.draw(c.resolve(Text("Av. Paulista").font(.system(size: fs * 0.62)).foregroundColor(.white)), at: CGPoint(x: ax + fs * 1.1, y: ay + fs * 0.45), anchor: .leading)
            c.draw(c.resolve(Text("12 min · 4,8 km").font(.system(size: fs * 0.7, weight: .bold)).foregroundColor(Color(hex: 0xe5e7eb))), at: CGPoint(x: r.maxX - fs * 0.4, y: r.maxY - fs * 0.35), anchor: .bottomTrailing)
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

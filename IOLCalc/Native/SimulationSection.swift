import SwiftUI
import IOLCore

// MARK: - 6 · Simulação visual

struct SimulationSection: View {
    @Bindable var model: CalculatorModel

    private var anyEye: Bool { model.eyeActive(.od) || model.eyeActive(.oe) }

    var body: some View {
        SectionCard(title: "6 · Simulação visual", trailing: AnyView(controls)) {
            MutedText("Cada quadro é um recorte ampliado do que o paciente vê a uma distância real, com o desfoque calculado da curva binocular resultante (lentes + residual + astigmatismo, se ligado). A ampliação é a mesma em todos os quadros: 1 minuto de arco = 2 px na tela, por isso a nitidez entre distâncias é comparável.", size: 12.5)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                ForEach(VisualSimulation.tiles) { tile in
                    tileView(tile)
                }
            }
            if anyEye {
                let dys = model.simulationDysphotopsia()
                if model.simulationNight {
                    (Text("À noite a combinação escolhida tende a disfotopsia ") + Text(VisualSimulation.dysphotopsiaLabels[dys]).bold()
                     + Text(" (classe das lentes). Use os botões para mostrar ao paciente a variação individual (\(VisualSimulation.haloModeLabels[model.simulationHaloMode])): alguns notam quase nada, a maioria nota halos ao dirigir, poucos têm queixa importante."))
                        .font(.system(size: 12)).foregroundStyle(Theme.muted)
                } else {
                    (Text("Quadros diurnos. Alterne para ") + Text("Noite").bold() + Text(" para ver a penalidade mesópica e os halos/starburst nas luzes."))
                        .font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
            }
            MutedText("Calibração: a AV prevista (logMAR) no defocus de cada distância vira um desfoque gaussiano com σ = 0,6·(MAR − 1) minutos de arco (MAR = 10^logMAR). À noite soma-se +0,08 logMAR (mesópico) e, nas fontes de luz distantes, halos e starburst com intensidade pela classe da lente (difrativas = mais). As ópticas difrativas perdem ≈0,1–0,2 log de sensibilidade ao contraste, e isso entra como redução de contraste do quadro. Os tamanhos são os reais: mensagem de celular 15 pt a 40 cm, e-mail 12 pt a 70 cm, GPS a 75 cm, placa com letras de 30 cm a 50 m.", size: 11.5)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Picker("", selection: $model.simulationNight) {
                Text("☀ Dia").tag(false)
                Text("🌙 Noite").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            if model.simulationNight {
                Picker("", selection: $model.simulationHaloMode) {
                    Text("melhor caso").tag(0)
                    Text("mais comum").tag(1)
                    Text("pior caso").tag(2)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
            }
        }
    }

    private func tileView(_ tile: VisualSimulation.Tile) -> some View {
        let acuity = model.simulationAcuity(tile)
        return VStack(spacing: 0) {
            HStack {
                Text(tile.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text(acuity.map { DefocusModel.snellen(fromLogMAR: $0) } ?? "—")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(acuity.map { $0 <= 0.2 ? ToricDiagram.green : ($0 <= 0.4 ? Theme.warn : Theme.od) } ?? Theme.muted)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.soft)
            SimulationTile(tile: tile, acuity: acuity, night: model.simulationNight, haloMode: model.simulationHaloMode,
                           dysphotopsia: model.simulationDysphotopsia(), astigmatism: model.simulationAstigmatism())
                .aspectRatio(VisualSimulation.tileWidth / VisualSimulation.tileHeight, contentMode: .fit)
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
    }
}

/// Um quadro da simulação: conteúdo nítido em tamanho físico, desfocado pela AV prevista,
/// arrastado pelo astigmatismo, com contraste reduzido e halos à noite. Porte do `renderTiles`.
struct SimulationTile: View {
    let tile: VisualSimulation.Tile
    /// AV (logMAR) do quadro; `nil` sem olho ativo (mostra o aviso).
    let acuity: Double?
    let night: Bool
    let haloMode: Int
    let dysphotopsia: Int
    let astigmatism: (cylinder: Double, axis: Double)?

    private typealias Light = TileScene.Light

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            render(&ctx, size: size)
        }
    }

    private func render(_ ctx: inout GraphicsContext, size: CGSize) {
        let W = VisualSimulation.tileWidth, H = VisualSimulation.tileHeight
        let s = size.width / W
        let font = SimulationFont.self
        ctx.clip(to: Path(CGRect(origin: .zero, size: size))) // halos e nuvens não vazam do quadro
        guard let acuity else {
            var c = ctx
            c.scaleBy(x: s, y: s)
            c.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)), with: .color(night ? Color(hex: 0x111827) : Color(hex: 0xe2e8f0)))
            c.draw(c.resolve(Text("Selecione a LIO (seção 2)").font(font.system(44, weight: .semibold)).foregroundColor(night ? Color(hex: 0x9ca3af) : Color(hex: 0x64748b))),
                   at: CGPoint(x: W / 2, y: H / 2), anchor: .center)
            return
        }
        let sigma = VisualSimulation.blurSigma(logMAR: acuity)
        let scene = TileScene(tile: tile, night: night)
        let blur: Double = sigma > 0.3 ? sigma * s : 0

        // conteúdo nítido → gaussiano (σ pela AV) → arrasto direcional (astigmatismo)
        let smear = astigmatism.map { VisualSimulation.directionalBlur(cylinder: $0.cylinder) } ?? 0
        if let astigmatism, astigmatism.cylinder > 0.1, smear >= 0.5 {
            let n = 12
            let rad = astigmatism.axis * .pi / 180
            let dx = cos(rad), dy = -sin(rad)
            for i in 0..<n {
                let t = (Double(i) / Double(n - 1) - 0.5) * 2 * smear
                ctx.drawLayer { layer in
                    layer.opacity = 1 / Double(n)
                    layer.translateBy(x: dx * t * s, y: dy * t * s)
                    if blur > 0 { layer.addFilter(.blur(radius: blur)) }
                    layer.scaleBy(x: s, y: s)
                    _ = scene.draw(&layer)
                }
            }
        } else {
            ctx.drawLayer { layer in
                if blur > 0 { layer.addFilter(.blur(radius: blur)) }
                layer.scaleBy(x: s, y: s)
                _ = scene.draw(&layer)
            }
        }

        // perda de contraste das ópticas difrativas
        let cf = VisualSimulation.contrast(dysphotopsia: dysphotopsia, night: night)
        if cf < 1 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.5, green: 0.5, blue: 0.5).opacity(1 - cf)))
        }

        if night {
            let lights = scene.lights
            if !lights.isEmpty { drawHalos(&ctx, lights: lights, scale: s) }
        }
    }

    /// Halos, anéis difrativos e starburst nas fontes de luz (`drawHalos` da web).
    private func drawHalos(_ ctx: inout GraphicsContext, lights: [Light], scale s: Double) {
        let I = VisualSimulation.haloIntensity(dysphotopsia: dysphotopsia, mode: haloMode)
        guard I >= 0.02 else { return }
        let pxa = VisualSimulation.pixelsPerArcMinute
        for (idx, L) in lights.enumerated() {
            let col = L.color, sz = min(L.strength, 1.35)
            let outer = L.radius + 40 + 120 * I * sz
            var c = ctx
            c.scaleBy(x: s, y: s)
            let center = CGPoint(x: L.x, y: L.y)
            c.fill(Path(ellipseIn: CGRect(x: L.x - outer, y: L.y - outer, width: 2 * outer, height: 2 * outer)),
                   with: .radialGradient(Gradient(colors: [col.opacity(min(0.5, 0.22 * I * sz)), col.opacity(0)]), center: center, startRadius: L.radius, endRadius: outer))
            guard dysphotopsia >= 1 else { continue }
            // anéis difrativos (raio angular ≈ 0,4–0,65°)
            let rings: [Double] = dysphotopsia >= 3 ? [24 * pxa, 39 * pxa] : [30 * pxa]
            for R in rings {
                let a = min(0.55, (dysphotopsia >= 3 ? 0.22 : 0.13) * I * sz)
                let rr = R * (1 + 0.08 * I)
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 6 * s))
                    layer.scaleBy(x: s, y: s)
                    layer.stroke(Path(ellipseIn: CGRect(x: L.x - rr, y: L.y - rr, width: 2 * rr, height: 2 * rr)), with: .color(col.opacity(a)), lineWidth: 5 * pxa / 2)
                }
            }
            // starburst
            let n = 16
            let base = (10 + 35 * I * sz) * pxa / 2
            let phase = (Double(idx) * 2.399).truncatingRemainder(dividingBy: 6.283)
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 1.5 * s))
                layer.scaleBy(x: s, y: s)
                for k in 0..<n {
                    let ang = Double(k) * .pi * 2 / Double(n) + phase
                    let len = base * (0.6 + 0.55 * abs(sin(Double(k) * 1.7 + Double(idx))))
                    let end = CGPoint(x: L.x + cos(ang) * len, y: L.y + sin(ang) * len)
                    var p = Path()
                    p.move(to: center)
                    p.addLine(to: end)
                    layer.stroke(p, with: .linearGradient(Gradient(colors: [col.opacity(min(0.6, 0.35 * I * sz)), col.opacity(0)]), startPoint: center, endPoint: end), lineWidth: 2.2)
                }
            }
        }
    }
}

/// Fonte dos quadros (sistema, como o `-apple-system` da web).
enum SimulationFont {
    static func system(_ size: Double, weight: Font.Weight = .regular) -> Font {
        .system(size: size.rounded(), weight: weight)
    }
}

/// Conteúdo nítido de cada quadro, em px de quadro (1120 × 720), tamanhos físicos reais.
/// `draw` devolve as fontes de luz (para os halos noturnos).
struct TileScene {
    struct Light {
        let x: Double, y: Double, radius: Double, strength: Double
        let color: Color
    }

    let tile: VisualSimulation.Tile
    let night: Bool

    private let W = VisualSimulation.tileWidth
    private let H = VisualSimulation.tileHeight
    private var cm: Double { tile.distanceCm }

    private func px(_ mm: Double) -> Double { VisualSimulation.pixels(forMillimetres: mm, at: cm) }

    /// Luzes do quadro (só a cena distante tem).
    var lights: [Light] { tile.id == "far" ? farLights : [] }

    @discardableResult
    func draw(_ c: inout GraphicsContext) -> [Light] {
        switch tile.id {
        case "phone": drawPhone(&c); return []
        case "laptop": drawLaptop(&c); return []
        case "gps": drawGPS(&c); return []
        default: drawFar(&c); return farLights
        }
    }

    private func rr(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }

    private func text(_ c: GraphicsContext, _ s: String, _ size: Double, _ color: Color, weight: Font.Weight = .regular) -> GraphicsContext.ResolvedText {
        c.resolve(Text(s).font(SimulationFont.system(size, weight: weight)).foregroundColor(color))
    }

    // Celular a 40 cm: mensagem de 15 pt (≈5,3 mm)
    private func drawPhone(_ c: inout GraphicsContext) {
        c.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)), with: .color(night ? Color(hex: 0x0b141a) : Color(hex: 0xe5ddd5)))
        let fs = px(5.3)
        let lines = ["Quinta, 8h30", "Dr. Hallim ✓"]
        let ink = night ? Color(hex: 0xe9edef) : Color(hex: 0x111b21)
        let resolved = lines.map { text(c, $0, fs, ink) }
        let w = (resolved.map { $0.measure(in: CGSize(width: 10_000, height: 10_000)).width }.max() ?? 0) + fs * 0.9
        let ts = px(3.5)
        let lh = fs * 1.22, h = lh * Double(lines.count) + fs * 0.8 + ts * 0.9 // + linha do horário
        let x = (W - w) / 2, y = (H - h) / 2
        c.fill(rr(x, y, w, h, fs * 0.35), with: .color(night ? Color(hex: 0x1f2c34) : .white))
        for (i, t) in resolved.enumerated() {
            c.draw(t, at: CGPoint(x: x + fs * 0.45, y: y + fs * 0.5 + lh * Double(i + 1) - lh * 0.22), anchor: .bottomLeading)
        }
        c.draw(text(c, "08:12", ts, night ? Color(hex: 0x8696a0) : Color(hex: 0x667781)), at: CGPoint(x: x + w - ts * 0.5, y: y + h - ts * 0.35), anchor: .bottomTrailing)
    }

    // Notebook a 70 cm: e-mail de 12 pt (≈4,2 mm)
    private func drawLaptop(_ c: inout GraphicsContext) {
        c.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)), with: .color(night ? Color(hex: 0x1e1e1e) : .white))
        let fs = px(4.2)
        let ink = night ? Color(hex: 0xd4d4d4) : Color(hex: 0x1f2937)
        let lines = ["Prezada Maria,", "confirmamos a sua", "cirurgia para quinta,", "dia 24, às 7h. Chegar", "em jejum de 8 horas."]
        let lh = fs * 1.45, y0 = (H - lh * Double(lines.count)) / 2 + fs
        for (i, l) in lines.enumerated() {
            c.draw(text(c, l, fs, ink), at: CGPoint(x: fs * 1.2, y: y0 + lh * Double(i)), anchor: .bottomLeading)
        }
    }

    // GPS a 75 cm
    private func drawGPS(_ c: inout GraphicsContext) {
        c.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)), with: .color(night ? Color(hex: 0x111827) : Color(hex: 0xe8ecef)))
        var road = Path()
        road.move(to: CGPoint(x: W * 0.62, y: H)); road.addLine(to: CGPoint(x: W * 0.62, y: H * 0.42)); road.addLine(to: CGPoint(x: W * 0.15, y: H * 0.42))
        c.stroke(road, with: .color(night ? Color(hex: 0x374151) : .white), lineWidth: px(9))
        var minor = Path()
        minor.move(to: CGPoint(x: 0, y: H * 0.75)); minor.addLine(to: CGPoint(x: W, y: H * 0.75))
        minor.move(to: CGPoint(x: W * 0.3, y: 0)); minor.addLine(to: CGPoint(x: W * 0.3, y: H * 0.42))
        c.stroke(minor, with: .color(night ? Color(hex: 0x4b5563) : Color(hex: 0xd1d5db)), lineWidth: px(4))
        c.stroke(road, with: .color(Color(hex: 0x2563eb)), style: StrokeStyle(lineWidth: px(5), lineCap: .round, lineJoin: .round))
        // painel de instrução
        let bh = px(22), bw = W * 0.56
        c.fill(rr(0, 0, bw, bh, px(3)), with: .color(night ? Color(hex: 0x064e3b) : Color(hex: 0x15803d)))
        let fs = px(7), fs2 = px(4)
        let ax = px(2) + fs * 0.2, ay = bh / 2
        var arrow = Path()
        arrow.move(to: CGPoint(x: ax + fs * 0.75, y: ay + fs * 0.55)); arrow.addLine(to: CGPoint(x: ax + fs * 0.75, y: ay - fs * 0.15)); arrow.addLine(to: CGPoint(x: ax + fs * 0.1, y: ay - fs * 0.15))
        arrow.move(to: CGPoint(x: ax + fs * 0.42, y: ay - fs * 0.5)); arrow.addLine(to: CGPoint(x: ax + fs * 0.05, y: ay - fs * 0.15)); arrow.addLine(to: CGPoint(x: ax + fs * 0.42, y: ay + fs * 0.2))
        c.stroke(arrow, with: .color(.white), style: StrokeStyle(lineWidth: fs * 0.16, lineCap: .round, lineJoin: .round))
        c.draw(text(c, "300 m", fs, .white, weight: .bold), at: CGPoint(x: ax + fs * 1.1, y: ay - fs * 0.22), anchor: .leading)
        c.draw(text(c, "Av. Paulista", fs2, .white), at: CGPoint(x: ax + fs * 1.1, y: ay + fs * 0.5), anchor: .leading)
        let s2 = px(5)
        c.draw(text(c, "12 min · 4,8 km", s2, night ? Color(hex: 0xe5e7eb) : Color(hex: 0x111827), weight: .bold), at: CGPoint(x: W - s2 * 0.6, y: H - s2 * 0.9), anchor: .bottomTrailing)
    }

    // Rua a 50 m: placa 2,0 × 1,0 m com letras de 30 cm, semáforo, carro à frente
    private var signFrame: (x: Double, y: Double, w: Double, h: Double) {
        (W - px(1600) - px(120), H * 0.1, px(1600), px(900))
    }

    private var farLights: [Light] {
        var lights: [Light] = []
        let sx = W * 0.035, sy = H * 0.08, sw = px(450), sh = px(1250), r = px(150)
        lights.append(Light(x: sx + sw / 2, y: sy + sh * 0.2, radius: r, strength: 1.0, color: Color(red: 1, green: 70 / 255, blue: 70 / 255)))
        let cw = px(1500), ch = px(1200), cx = W * 0.36 - cw / 2, cy = H * 0.66 - ch * 0.95
        if night {
            for lx in [cx + cw * 0.14, cx + cw * 0.86] {
                lights.append(Light(x: lx, y: cy + ch * 0.4, radius: px(150), strength: 0.9, color: Color(red: 1, green: 60 / 255, blue: 50 / 255)))
            }
            for (lx, ly) in [(W * 0.86, H * 0.08), (W * 0.97, H * 0.26)] {
                lights.append(Light(x: lx, y: ly, radius: px(400), strength: 1.2, color: Color(red: 1, green: 244 / 255, blue: 210 / 255)))
            }
        }
        return lights
    }

    private func drawFar(_ c: inout GraphicsContext) {
        let skyColors = night ? [Color(hex: 0x020617), Color(hex: 0x111a2e)] : [Color(hex: 0x7fb3e6), Color(hex: 0xd6ebfa)]
        c.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)), with: .linearGradient(Gradient(colors: skyColors), startPoint: .zero, endPoint: CGPoint(x: 0, y: H * 0.66)))
        c.fill(Path(CGRect(x: 0, y: H * 0.66, width: W, height: H)), with: .color(night ? Color(hex: 0x1f2937) : Color(hex: 0x6b7280)))
        var lane = Path()
        lane.move(to: CGPoint(x: W * 0.66, y: H * 0.66)); lane.addLine(to: CGPoint(x: W * 0.66, y: H))
        c.stroke(lane, with: .color(night ? Color(hex: 0x9ca3af) : Color(hex: 0xf3f4f6)), style: StrokeStyle(lineWidth: px(120), dash: [px(1500), px(1500)]))
        // placa
        let lt = px(250)
        let (sx0, sy0, pw, ph) = signFrame
        c.fill(rr(sx0, sy0, pw, ph, px(60)), with: .color(night ? Color(hex: 0x0f5132) : Color(hex: 0x15803d)))
        c.stroke(rr(sx0, sy0, pw, ph, px(60)), with: .color(.white), lineWidth: px(40))
        c.draw(text(c, "SAÍDA 12", lt, .white, weight: .bold), at: CGPoint(x: sx0 + pw / 2, y: sy0 + ph * 0.34), anchor: .center)
        c.draw(text(c, "Centro  →", lt * 0.78, .white), at: CGPoint(x: sx0 + pw / 2, y: sy0 + ph * 0.72), anchor: .center)
        let post = night ? Color(hex: 0x374151) : Color(hex: 0x4b5563)
        c.fill(Path(CGRect(x: sx0 + pw / 2 - px(60), y: sy0 + ph, width: px(120), height: H * 0.66 - sy0 - ph)), with: .color(post))
        // semáforo
        let sx = W * 0.035, sy = H * 0.08, sw = px(450), sh = px(1250), r = px(150)
        c.fill(rr(sx, sy, sw, sh, px(80)), with: .color(Color(hex: 0x111827)))
        for (i, col) in [Color(hex: 0xef4444), Color(hex: 0xf59e0b), Color(hex: 0x22c55e)].enumerated() {
            let cy = sy + sh * (0.2 + 0.3 * Double(i))
            c.fill(Path(ellipseIn: CGRect(x: sx + sw / 2 - r, y: cy - r, width: 2 * r, height: 2 * r)), with: .color(i == 0 ? col : (night ? Color(hex: 0x1f2937) : Color(hex: 0x374151))))
        }
        c.fill(Path(CGRect(x: sx + sw / 2 - px(60), y: sy + sh, width: px(120), height: H * 0.66 - sy - sh)), with: .color(post))
        // carro à frente
        let cw = px(1500), ch = px(1200), cx = W * 0.36 - cw / 2, cy = H * 0.66 - ch * 0.95
        c.fill(rr(cx + cw * 0.12, cy - ch * 0.4, cw * 0.76, ch * 0.5, px(150)), with: .color(night ? Color(hex: 0x0f172a) : Color(hex: 0x1e293b)))
        c.fill(rr(cx, cy, cw, ch, px(200)), with: .color(night ? Color(hex: 0x111827) : Color(hex: 0x334155)))
        for lx in [cx + cw * 0.14, cx + cw * 0.86] {
            let lr = px(150), ly = cy + ch * 0.4
            c.fill(Path(ellipseIn: CGRect(x: lx - lr * 1.4, y: ly - lr, width: lr * 2.8, height: lr * 2)), with: .color(night ? Color(hex: 0xff3b30) : Color(hex: 0xb91c1c)))
        }
        if night {
            for (lx, ly) in [(W * 0.86, H * 0.08), (W * 0.97, H * 0.26)] {
                let lr = px(400)
                c.fill(Path(ellipseIn: CGRect(x: lx - lr, y: ly - lr, width: 2 * lr, height: 2 * lr)), with: .color(Color(hex: 0xfff7d6)))
            }
        } else {
            for (x, y, r2) in [(W * 0.3, H * 0.05, px(700)), (W * 0.55, H * 0.04, px(500))] {
                c.fill(Path(ellipseIn: CGRect(x: x - r2, y: y - r2 * 0.4, width: 2 * r2, height: r2 * 0.8)), with: .color(Color.white.opacity(0.7)))
            }
        }
    }
}

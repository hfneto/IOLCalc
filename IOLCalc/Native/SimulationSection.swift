import SwiftUI
import IOLCore

// MARK: - 6 · Simulação visual (cenas fotográficas)

struct SimulationSection: View {
    @Bindable var model: CalculatorModel

    private var anyEye: Bool { model.eyeActive(.od) || model.eyeActive(.oe) }

    var body: some View {
        SectionCard(title: "6 · Simulação visual") {
            MutedText("Duas cenas com as três distâncias: de dia, numa cafeteria (celular na mão a 40 cm, e-mail no notebook a 66 cm, cardápio, quadros e a rua pela janela); à noite, dirigindo (celular na mão, GPS do carro a 66 cm, o carro à frente com a placa, semáforo, placas e luzes da cidade). Cada camada é desfocada pela AV binocular prevista naquela distância (lentes + residual + astigmatismo, se ligado). À noite entram a penalidade mesópica e os halos nas luzes.", size: 12.5)
            sceneBlock(.day)
            sceneBlock(.night)
            if anyEye {
                let dys = model.simulationDysphotopsia()
                (Text("À noite a combinação escolhida tende a disfotopsia ") + Text(VisualSimulation.dysphotopsiaLabels[dys]).bold()
                 + Text(" (classe das lentes). Use os botões da cena noturna para mostrar ao paciente a variação individual (\(VisualSimulation.haloModeLabels[model.simulationHaloMode])): alguns notam quase nada, a maioria nota halos ao dirigir, poucos têm queixa importante."))
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            MutedText("Calibração: a AV prevista (logMAR) no defocus de cada distância vira um desfoque gaussiano com σ = 0,6·(MAR − 1) minutos de arco (MAR = 10^logMAR), a 2 px por minuto de arco. À noite soma-se +0,08 logMAR (mesópico); nas luzes, halos, anéis e starburst com intensidade pela classe da lente (difrativas = mais). As ópticas difrativas perdem ≈0,1–0,2 log de sensibilidade ao contraste, aplicado como redução de contraste. Cenas geradas por IA (Gemini) a partir da descrição do usuário; as telas são desenhadas pelo app.", size: 11.5)
        }
    }

    private func sceneBlock(_ scene: SimulationScene) -> some View {
        let acuities = VisualSimulation.distances.map { model.simulationAcuity($0, night: scene.night) }
        return VStack(spacing: 0) {
            Group {
                #if os(iOS)
                VStack(alignment: .leading, spacing: 6) {
                    header(scene, acuities)
                    if scene.night { haloPicker }
                }
                #else
                HStack(spacing: 10) {
                    header(scene, acuities)
                    Spacer(minLength: 0)
                    if scene.night { haloPicker }
                }
                #endif
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
        FlowLayout(spacing: 10) {
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

    /// Os quatro cantos de uma tela na foto (normalizados, na ordem superior-esquerdo, superior-direito,
    /// inferior-esquerdo, inferior-direito). O conteúdo é desenhado num retângulo local e projetado
    /// para o quadrilátero por uma homografia, respeitando a perspectiva da foto.
    struct Quad {
        let tl: CGPoint, tr: CGPoint, bl: CGPoint, br: CGPoint
        init(_ tl: (Double, Double), _ tr: (Double, Double), _ bl: (Double, Double), _ br: (Double, Double)) {
            self.tl = CGPoint(x: tl.0, y: tl.1); self.tr = CGPoint(x: tr.0, y: tr.1)
            self.bl = CGPoint(x: bl.0, y: bl.1); self.br = CGPoint(x: br.0, y: br.1)
        }
    }

    let imageName: String
    let night: Bool
    /// O que está longe (rua, vitrine, parede do fundo) e o que está a 40 cm (mão com o celular).
    let farPolygons: [[CGPoint]]
    let nearPolygons: [[CGPoint]]
    let phoneScreen: Quad
    let midScreen: Quad
    let lights: [Light]

    private static func poly(_ pts: [(Double, Double)]) -> [CGPoint] { pts.map { CGPoint(x: $0.0, y: $0.1) } }

    /// Cafeteria de dia (imagem gerada com o Gemini a partir da descrição do usuário).
    static let day = SimulationScene(
        imageName: "sim-day", night: false,
        farPolygons: [poly([(0.0, 0.0), (1.0, 0.0), (1.0, 0.73), (0.72, 0.62), (0.53, 0.50), (0.30, 0.54), (0.0, 0.60)])],
        nearPolygons: [poly([(0.452, 0.515), (0.567, 0.540), (0.585, 0.62), (0.60, 0.72), (0.585, 0.90), (0.56, 1.0), (0.27, 1.0),
                             (0.30, 0.86), (0.34, 0.72), (0.37, 0.63), (0.42, 0.62), (0.455, 0.57)])],
        phoneScreen: Quad((0.4665, 0.5263), (0.5677, 0.5627), (0.3988, 0.8854), (0.5183, 0.9360)),
        midScreen: Quad((0.3083, 0.3507), (0.5171, 0.3412), (0.3166, 0.5606), (0.5272, 0.5311)),
        lights: [])

    /// Direção à noite (imagem gerada com o Gemini a partir da descrição do usuário).
    static let night = SimulationScene(
        imageName: "sim-night", night: true,
        farPolygons: [poly([(0.04, 0.03), (1.0, 0.0), (1.0, 0.58), (0.72, 0.56), (0.40, 0.56), (0.17, 0.56), (0.05, 0.45)])],
        nearPolygons: [poly([(0.72, 0.365), (0.885, 0.36), (0.89, 0.50), (1.0, 0.56), (1.0, 1.0), (0.70, 1.0), (0.70, 0.55)])],
        phoneScreen: Quad((0.7351, 0.4343), (0.8655, 0.4306), (0.7405, 0.7991), (0.8750, 0.7972)),
        midScreen: Quad((0.5935, 0.7602), (0.7660, 0.7625), (0.5964, 0.9065), (0.7680, 0.9120)),
        lights: [
            // semáforo
            Light(x: 0.543, y: 0.022, radius: 0.012, strength: 1.2, color: Color(red: 1, green: 0.25, blue: 0.2)),
            Light(x: 0.655, y: 0.022, radius: 0.012, strength: 1.2, color: Color(red: 1, green: 0.25, blue: 0.2)),
            // carro à frente: lanternas e luz de freio
            Light(x: 0.438, y: 0.431, radius: 0.010, strength: 1.0, color: Color(red: 1, green: 0.3, blue: 0.2)),
            Light(x: 0.653, y: 0.433, radius: 0.010, strength: 1.0, color: Color(red: 1, green: 0.3, blue: 0.2)),
            Light(x: 0.546, y: 0.370, radius: 0.007, strength: 0.8, color: Color(red: 1, green: 0.3, blue: 0.2)),
            // faróis dos carros que vêm de frente
            Light(x: 0.395, y: 0.414, radius: 0.007, strength: 1.0, color: Color(red: 1, green: 0.97, blue: 0.9)),
            Light(x: 0.352, y: 0.414, radius: 0.006, strength: 0.9, color: Color(red: 1, green: 0.97, blue: 0.9)),
            Light(x: 0.321, y: 0.415, radius: 0.005, strength: 0.8, color: Color(red: 1, green: 0.97, blue: 0.9)),
            Light(x: 0.428, y: 0.370, radius: 0.005, strength: 0.7, color: Color(red: 1, green: 0.97, blue: 0.9)),
            // postes e letreiros
            Light(x: 0.324, y: 0.063, radius: 0.006, strength: 0.9, color: Color(red: 0.9, green: 0.95, blue: 1)),
            Light(x: 0.643, y: 0.150, radius: 0.005, strength: 0.7, color: Color(red: 0.9, green: 0.95, blue: 1)),
            Light(x: 0.752, y: 0.189, radius: 0.012, strength: 0.6, color: Color(red: 0.8, green: 0.9, blue: 1)),
        ])

    func path(_ polys: [[CGPoint]], width W: Double, height H: Double) -> Path {
        var p = Path()
        for poly in polys {
            guard let f = poly.first else { continue }
            p.move(to: CGPoint(x: f.x * W, y: f.y * H))
            for pt in poly.dropFirst() { p.addLine(to: CGPoint(x: pt.x * W, y: pt.y * H)) }
            p.closeSubpath()
        }
        return p
    }
}

/// Desenha uma cena: a foto com as telas preenchidas, em três camadas desfocadas (painel/mesa a
/// 66 cm, o que está longe, a mão com o celular a 40 cm), mais contraste, halos noturnos e o
/// arrasto do astigmatismo.
struct SimulationSceneView: View {
    let scene: SimulationScene
    /// AV (logMAR) nas distâncias de `VisualSimulation.distances` (perto, 66 cm, longe); `nil` sem olho ativo.
    let acuities: [Double?]
    let haloMode: Int
    let dysphotopsia: Int
    let astigmatism: (cylinder: Double, axis: Double)?

    private let W = VisualSimulation.sceneWidth
    private let H = VisualSimulation.sceneHeight

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            render(&ctx, size: size)
        }
    }

    private func render(_ ctx: inout GraphicsContext, size: CGSize) {
        let s = size.width / W
        ctx.clip(to: Path(CGRect(origin: .zero, size: size)))
        let photo = ctx.resolve(Image(scene.imageName))
        guard acuities.count == 3, let near = acuities[0], let mid = acuities[1], let far = acuities[2] else {
            ctx.drawLayer { l in l.scaleBy(x: s, y: s); drawScene(&l, photo: photo) }
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.55)))
            ctx.draw(ctx.resolve(Text("Selecione a LIO (seção 2)").font(.system(size: 44 * s, weight: .semibold)).foregroundColor(.white)),
                     at: CGPoint(x: size.width / 2, y: size.height / 2), anchor: .center)
            return
        }
        let k = VisualSimulation.sceneBlurPixelsPerArcMinute
        let sigma = (near: VisualSimulation.blurSigma(logMAR: near, pixelsPerArcMinute: k) * s,
                     mid: VisualSimulation.blurSigma(logMAR: mid, pixelsPerArcMinute: k) * s,
                     far: VisualSimulation.blurSigma(logMAR: far, pixelsPerArcMinute: k) * s)

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
                    l.blendMode = .normal       // …mas dentro da cópia as camadas se cobrem normalmente
                    l.opacity = 1
                    l.translateBy(x: dx * t * s, y: dy * t * s)
                    composite(&l, s: s, photo: photo, sigma: sigma)
                }
            }
        } else {
            composite(&ctx, s: s, photo: photo, sigma: sigma)
        }

        let cf = VisualSimulation.contrast(dysphotopsia: dysphotopsia, night: scene.night)
        if cf < 1 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.5, green: 0.5, blue: 0.5).opacity(1 - cf)))
        }
        if scene.night { drawNightLights(&ctx, s: s) }
    }

    /// Camada base a 66 cm (foto inteira) → o que está longe (recorte) → a mão com o celular (recorte).
    private func composite(_ ctx: inout GraphicsContext, s: Double, photo: GraphicsContext.ResolvedImage,
                           sigma: (near: Double, mid: Double, far: Double)) {
        ctx.drawLayer { l in
            if sigma.mid > 0.3 { l.addFilter(.blur(radius: sigma.mid)) }
            l.scaleBy(x: s, y: s)
            drawScene(&l, photo: photo)
        }
        // Máscaras com borda suave (≈ 6 px da foto): o limite entre uma camada nítida e outra desfocada
        // deixava uma emenda dura na borda dos polígonos.
        let feather = 6 * s
        var farCtx = ctx
        farCtx.clipToLayer { m in
            m.addFilter(.blur(radius: feather))
            m.fill(scene.path(scene.farPolygons, width: W * s, height: H * s), with: .color(.black))
        }
        farCtx.drawLayer { l in
            if sigma.far > 0.3 { l.addFilter(.blur(radius: sigma.far)) }
            l.scaleBy(x: s, y: s)
            drawScene(&l, photo: photo)
        }
        var nearCtx = ctx
        nearCtx.clipToLayer { m in
            m.addFilter(.blur(radius: feather))
            m.fill(scene.path(scene.nearPolygons, width: W * s, height: H * s), with: .color(.black))
        }
        nearCtx.drawLayer { l in
            if sigma.near > 0.3 { l.addFilter(.blur(radius: sigma.near)) }
            l.scaleBy(x: s, y: s)
            drawScene(&l, photo: photo)
        }
    }

    /// A foto com as duas telas preenchidas (mensagem no celular; e-mail ou GPS a 66 cm).
    private func drawScene(_ c: inout GraphicsContext, photo: GraphicsContext.ResolvedImage) {
        c.draw(photo, in: CGRect(x: 0, y: 0, width: W, height: H))
        // A tela a 66 cm fica atrás da mão: desenhada primeiro e recortada fora da região "perto".
        var behind = c
        var exclusion = Path(CGRect(x: 0, y: 0, width: W, height: H))
        exclusion.addPath(scene.path(scene.nearPolygons, width: W, height: H))
        behind.clip(to: exclusion, style: FillStyle(eoFill: true))
        drawInQuad(&behind, scene.midScreen) { c, w, h in
            if scene.night { drawNavigationUI(&c, w: w, h: h) } else { drawEmailUI(&c, w: w, h: h) }
        }
        drawInQuad(&c, scene.phoneScreen) { c, w, h in drawPhoneUI(&c, w: w, h: h) }
    }

    /// Desenha o conteúdo num retângulo local (0,0,w,h) e projeta-o no quadrilátero da foto com
    /// uma homografia (filtro `projectionTransform`), para acompanhar a perspectiva da tela.
    private func drawInQuad(_ ctx: inout GraphicsContext, _ q: SimulationScene.Quad, _ body: (inout GraphicsContext, Double, Double) -> Void) {
        let tl = CGPoint(x: q.tl.x * W, y: q.tl.y * H), tr = CGPoint(x: q.tr.x * W, y: q.tr.y * H)
        let bl = CGPoint(x: q.bl.x * W, y: q.bl.y * H), br = CGPoint(x: q.br.x * W, y: q.br.y * H)
        let w = (hypot(tr.x - tl.x, tr.y - tl.y) + hypot(br.x - bl.x, br.y - bl.y)) / 2
        let h = (hypot(bl.x - tl.x, bl.y - tl.y) + hypot(br.x - tr.x, br.y - tr.y)) / 2
        guard let m = Self.homography(from: [CGPoint(x: 0, y: 0), CGPoint(x: w, y: 0), CGPoint(x: 0, y: h), CGPoint(x: w, y: h)], to: [tl, tr, bl, br]) else { return }
        ctx.drawLayer { l in
            // ProjectionTransform aplica p' = p · M (vetor-linha): M é a transposta da matriz linha-major.
            var t = ProjectionTransform()
            t.m11 = m[0]; t.m12 = m[3]; t.m13 = m[6]
            t.m21 = m[1]; t.m22 = m[4]; t.m23 = m[7]
            t.m31 = m[2]; t.m32 = m[5]; t.m33 = m[8]
            l.addFilter(.projectionTransform(t))
            l.clip(to: Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: min(w, h) * 0.06))
            body(&l, w, h)
        }
    }

    /// Homografia 3×3 (linha-major: [a b c; d e f; g h 1]) que leva 4 pontos de origem aos 4 de destino.
    static func homography(from src: [CGPoint], to dst: [CGPoint]) -> [CGFloat]? {
        // 8 equações lineares em (a,b,c,d,e,f,g,h)
        var A = [[Double]](); var B = [Double]()
        for i in 0..<4 {
            let x = Double(src[i].x), y = Double(src[i].y), u = Double(dst[i].x), v = Double(dst[i].y)
            A.append([x, y, 1, 0, 0, 0, -u * x, -u * y]); B.append(u)
            A.append([0, 0, 0, x, y, 1, -v * x, -v * y]); B.append(v)
        }
        // eliminação de Gauss com pivotamento parcial
        let n = 8
        for col in 0..<n {
            var piv = col
            for r in col + 1..<n where abs(A[r][col]) > abs(A[piv][col]) { piv = r }
            if abs(A[piv][col]) < 1e-12 { return nil }
            if piv != col { A.swapAt(piv, col); B.swapAt(piv, col) }
            for r in 0..<n where r != col {
                let f = A[r][col] / A[col][col]
                if f == 0 { continue }
                for c in col..<n { A[r][c] -= f * A[col][c] }
                B[r] -= f * B[col]
            }
        }
        let sol = (0..<n).map { B[$0] / A[$0][$0] }
        return (sol + [1]).map { CGFloat($0) }
    }

    /// Conversa de mensagens (texto ≈ 8 % da largura da tela, como 15 pt num celular a 40 cm).
    private func drawPhoneUI(_ c: inout GraphicsContext, w: Double, h: Double) {
        let night = scene.night
        c.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(night ? Color(hex: 0x0b141a) : Color(hex: 0xe5ddd5)))
        let fs = w * 0.083
        let bar = CGRect(x: 0, y: 0, width: w, height: fs * 3.0)
        c.fill(Path(bar), with: .color(night ? Color(hex: 0x1f2c34) : Color(hex: 0x075e54)))
        let av = CGRect(x: fs * 0.6, y: bar.maxY - fs * 1.6, width: fs * 1.15, height: fs * 1.15)
        c.fill(Path(ellipseIn: av), with: .color(Color(hex: 0x94a3b8)))
        c.draw(c.resolve(Text("Dr. Hallim").font(.system(size: fs * 0.9, weight: .semibold)).foregroundColor(.white)),
               at: CGPoint(x: av.maxX + fs * 0.5, y: av.midY), anchor: .leading)
        func bubble(_ lines: [String], y: Double, mine: Bool) -> Double {
            let texts = lines.map { c.resolve(Text($0).font(.system(size: fs)).foregroundColor(night ? Color(hex: 0xe9edef) : Color(hex: 0x111b21))) }
            let bw = (texts.map { $0.measure(in: CGSize(width: 10_000, height: 10_000)).width }.max() ?? 0) + fs * 1.2
            let lh = fs * 1.3, bh = lh * Double(lines.count) + fs * 0.9
            let x = mine ? w - fs * 0.5 - bw : fs * 0.5
            let bg: Color = mine ? (night ? Color(hex: 0x005c4b) : Color(hex: 0xdcf8c6)) : (night ? Color(hex: 0x202c33) : .white)
            c.fill(Path(roundedRect: CGRect(x: x, y: y, width: bw, height: bh), cornerRadius: fs * 0.5), with: .color(bg))
            for (i, t) in texts.enumerated() { c.draw(t, at: CGPoint(x: x + fs * 0.6, y: y + fs * 0.45 + lh * Double(i)), anchor: .topLeading) }
            return y + bh + fs * 0.6
        }
        var y = bar.maxY + fs * 0.8
        y = bubble(["Bom dia! Sua cirurgia", "ficou para quinta,", "às 8h30."], y: y, mine: false)
        y = bubble(["Chegar em jejum", "de 8 horas."], y: y, mine: false)
        _ = bubble(["Combinado, obrigada!"], y: y, mine: true)
        c.draw(c.resolve(Text("08:12").font(.system(size: fs * 0.7)).foregroundColor(night ? Color(hex: 0x8696a0) : Color(hex: 0x667781))),
               at: CGPoint(x: w - fs * 0.6, y: h - fs * 0.5), anchor: .bottomTrailing)
    }

    /// E-mail na tela do notebook (texto maior que o físico: a foto tem campo largo).
    private func drawEmailUI(_ c: inout GraphicsContext, w sw: Double, h sh: Double) {
        let r = CGRect(x: 0, y: 0, width: sw, height: sh)
        c.fill(Path(r), with: .color(Color(hex: 0xf3f4f6)))
        let fs = sw * 0.045
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
    }

    /// GPS na tela do painel.
    private func drawNavigationUI(_ c: inout GraphicsContext, w: Double, h: Double) {
        let r = CGRect(x: 0, y: 0, width: w, height: h)
        c.fill(Path(r), with: .color(Color(hex: 0x1f2937)))
        var road = Path()
        road.move(to: CGPoint(x: w * 0.55, y: h)); road.addLine(to: CGPoint(x: w * 0.55, y: h * 0.55)); road.addLine(to: CGPoint(x: w * 0.2, y: h * 0.55))
        c.stroke(road, with: .color(Color(hex: 0x374151)), lineWidth: w * 0.09)
        c.stroke(road, with: .color(Color(hex: 0x3b82f6)), style: StrokeStyle(lineWidth: w * 0.045, lineCap: .round, lineJoin: .round))
        var minor = Path()
        minor.move(to: CGPoint(x: 0, y: h * 0.8)); minor.addLine(to: CGPoint(x: w, y: h * 0.8))
        minor.move(to: CGPoint(x: w * 0.8, y: 0)); minor.addLine(to: CGPoint(x: w * 0.8, y: h))
        c.stroke(minor, with: .color(Color(hex: 0x374151)), lineWidth: w * 0.04)
        let bh = h * 0.36
        c.fill(Path(CGRect(x: 0, y: 0, width: w, height: bh)), with: .color(Color(hex: 0x15803d)))
        let fs = w * 0.11
        let ax = fs * 0.4, ay = bh / 2
        var arrow = Path()
        arrow.move(to: CGPoint(x: ax + fs * 0.75, y: ay + fs * 0.55)); arrow.addLine(to: CGPoint(x: ax + fs * 0.75, y: ay - fs * 0.15)); arrow.addLine(to: CGPoint(x: ax + fs * 0.1, y: ay - fs * 0.15))
        arrow.move(to: CGPoint(x: ax + fs * 0.42, y: ay - fs * 0.5)); arrow.addLine(to: CGPoint(x: ax + fs * 0.05, y: ay - fs * 0.15)); arrow.addLine(to: CGPoint(x: ax + fs * 0.42, y: ay + fs * 0.2))
        c.stroke(arrow, with: .color(.white), style: StrokeStyle(lineWidth: fs * 0.16, lineCap: .round, lineJoin: .round))
        c.draw(c.resolve(Text("300 m").font(.system(size: fs, weight: .bold)).foregroundColor(.white)), at: CGPoint(x: ax + fs * 1.1, y: ay - fs * 0.25), anchor: .leading)
        c.draw(c.resolve(Text("Av. Paulista").font(.system(size: fs * 0.62)).foregroundColor(.white)), at: CGPoint(x: ax + fs * 1.1, y: ay + fs * 0.45), anchor: .leading)
        c.draw(c.resolve(Text("12 min · 4,8 km").font(.system(size: fs * 0.7, weight: .bold)).foregroundColor(Color(hex: 0xe5e7eb))), at: CGPoint(x: w - fs * 0.4, y: h - fs * 0.35), anchor: .bottomTrailing)
    }

    /// Halo, anéis difrativos e starburst nas luzes conhecidas da cena.
    private func drawNightLights(_ ctx: inout GraphicsContext, s: Double) {
        let I = VisualSimulation.haloIntensity(dysphotopsia: dysphotopsia, mode: haloMode)
        guard I >= 0.02 else { return }
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

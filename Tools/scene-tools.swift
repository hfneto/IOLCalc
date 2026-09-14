// Ferramentas para preparar as cenas da simulação visual (compilar: swiftc -O Tools/scene-tools.swift -o /tmp/scene-tools).
//   screen <foto> <x> <y> <tolerância>      → cantos de uma tela uniforme (preenchimento por cor a partir do ponto), normalizados
//   grid <foto> <saída.jpg> <x0> <y0> <w> <h> <passo>  → recorte com grade numerada, para ler coordenadas
//   mask <foto> <saída.jpg> x1 y1 x2 y2 …    → polígono translúcido sobre a foto (conferir máscaras "longe"/"perto")
//   blobs <foto> <lumMin> <yMax>             → manchas claras (luzes) com centro, raio e cor
//   hand <foto> <saída.png>                  → recorta ao conteúdo com alfa (usado na versão com PNG da mão)
import AppKit
import CoreGraphics
func load(_ p: String) -> CGImage { NSImage(contentsOfFile: p)!.cgImage(forProposedRect: nil, context: nil, hints: nil)! }
func savePNG(_ img: CGImage, _ p: String) { let rep = NSBitmapImageRep(cgImage: img); try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: p)) }
func saveJPG(_ img: CGImage, _ p: String) { let rep = NSBitmapImageRep(cgImage: img); try! rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])!.write(to: URL(fileURLWithPath: p)) }
func pixels(_ img: CGImage) -> ([UInt8], Int, Int) {
    let w = img.width, h = img.height; var d = [UInt8](repeating: 0, count: w*h*4)
    let c = CGContext(data: &d, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h)); return (d, w, h)
}
let cmd = CommandLine.arguments[1]
switch cmd {
case "hand": // crop cutout to alpha box, find screen (white) box, downscale to width 900
    let img = load(CommandLine.arguments[2]); let (d, w, h) = pixels(img)
    var minX = w, minY = h, maxX = 0, maxY = 0; var sminX = w, sminY = h, smaxX = 0, smaxY = 0
    for y in 0..<h { for x in 0..<w { let i = (y*w+x)*4; if d[i+3] > 20 { minX = min(minX,x); maxX = max(maxX,x); minY = min(minY,y); maxY = max(maxY,y)
        if d[i] > 215 && d[i+1] > 215 && d[i+2] > 215 && d[i+3] > 250 { sminX = min(sminX,x); smaxX = max(smaxX,x); sminY = min(sminY,y); smaxY = max(smaxY,y) } } } }
    // CG y is bottom-up in the context? We drew with default (flipped) so row 0 = top after draw? CGContext.draw draws with origin bottom-left → row 0 is bottom. Convert to top-down.
    func td(_ y: Int) -> Int { h - 1 - y }
    let box = CGRect(x: minX, y: minY, width: maxX-minX+1, height: maxY-minY+1)
    let cropped = img.cropping(to: CGRect(x: box.minX, y: CGFloat(h) - box.maxY, width: box.width, height: box.height))!  // cropping uses top-down coords
    let scale = 900.0 / Double(cropped.width)
    let nw = Int(Double(cropped.width)*scale), nh = Int(Double(cropped.height)*scale)
    let ctx = CGContext(data: nil, width: nw, height: nh, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high; ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: nw, height: nh))
    savePNG(ctx.makeImage()!, CommandLine.arguments[3])
    // screen box normalized to the cropped image (top-down)
    let sx0 = (Double(sminX) - box.minX) / box.width, sx1 = (Double(smaxX+1) - box.minX) / box.width
    let sy0 = (Double(td(smaxY)) - (Double(h) - box.maxY)) / box.height, sy1 = (Double(td(sminY)+1) - (Double(h) - box.maxY)) / box.height
    print("hand out \(nw)x\(nh) screen(normalized, top-down): x \(sx0)...\(sx1) y \(sy0)...\(sy1)")
case "blobs": // bright blobs: args image, minLum(0-1), maxY(normalized top-down)
    let img = load(CommandLine.arguments[2]); let minLum = Double(CommandLine.arguments[3])!; let maxYn = Double(CommandLine.arguments[4])!
    let (d, w, h) = pixels(img)
    let s = 4; let sw = w/s, sh = h/s
    var bright = [Bool](repeating: false, count: sw*sh)
    for y in 0..<sh { for x in 0..<sw { var lum = 0.0; var n = 0.0
        for dy in 0..<s { for dx in 0..<s { let px = x*s+dx, py = y*s+dy; let i = (py*w+px)*4; lum += (0.299*Double(d[i]) + 0.587*Double(d[i+1]) + 0.114*Double(d[i+2]))/255; n += 1 } }
        bright[y*sw+x] = lum/n > minLum } }
    var seen = [Bool](repeating: false, count: sw*sh); var blobs: [(Double, Double, Double, Double, Double, Double)] = []
    for y in 0..<sh { for x in 0..<sw where bright[y*sw+x] && !seen[y*sw+x] {
        var stack = [(x,y)]; seen[y*sw+x] = true; var pts: [(Int,Int)] = []
        while let (cx, cy) = stack.popLast() { pts.append((cx,cy)); for (nx,ny) in [(cx+1,cy),(cx-1,cy),(cx,cy+1),(cx,cy-1)] where nx >= 0 && ny >= 0 && nx < sw && ny < sh && bright[ny*sw+nx] && !seen[ny*sw+nx] { seen[ny*sw+nx] = true; stack.append((nx,ny)) } }
        if pts.count < 2 { continue }
        let cx = Double(pts.map{$0.0}.reduce(0,+))/Double(pts.count), cy = Double(pts.map{$0.1}.reduce(0,+))/Double(pts.count)
        // mean color at centroid area
        var r = 0.0, g = 0.0, b = 0.0; for (px,py) in pts { let i = ((py*s)*w+px*s)*4; r += Double(d[i]); g += Double(d[i+1]); b += Double(d[i+2]) }
        let cnt = Double(pts.count)
        let yTop = (cy+0.5)/Double(sh)   // linhas do bitmap são de cima para baixo
        if yTop <= maxYn { blobs.append(((cx+0.5)/Double(sw), yTop, (cnt/Double.pi).squareRoot()*Double(s)/Double(w), r/cnt/255, g/cnt/255, b/cnt/255)) }
    } }
    for b in blobs.sorted(by: { $0.2 > $1.2 }).prefix(20) { print(String(format: "x %.3f y %.3f r %.4f rgb %.2f %.2f %.2f", b.0, b.1, b.2, b.3, b.4, b.5)) }
case "mask": // draw polygon overlay: args image, out, then x,y pairs normalized top-down
    let img = load(CommandLine.arguments[2]); let w = img.width, h = img.height
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    let nums = CommandLine.arguments[4...].map { Double($0)! }
    ctx.setFillColor(CGColor(red: 1, green: 0, blue: 1, alpha: 0.35)); ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 0, alpha: 1)); ctx.setLineWidth(4)
    var i = 0; while i < nums.count { let p = CGPoint(x: nums[i]*Double(w), y: (1-nums[i+1])*Double(h)); if i == 0 { ctx.move(to: p) } else { ctx.addLine(to: p) }; i += 2 }
    ctx.closePath(); ctx.drawPath(using: .fillStroke)
    saveJPG(ctx.makeImage()!, CommandLine.arguments[3])
case "grid": // recorte com grade: args imagem, out, x0 y0 w h (px), passo
    let img = load(CommandLine.arguments[2]); let a = CommandLine.arguments[4...].map { Int($0)! }
    let x0 = a[0], y0 = a[1], cw = a[2], chh = a[3], step = a[4]
    let cropped = img.cropping(to: CGRect(x: x0, y: y0, width: cw, height: chh))!
    let ctx = CGContext(data: nil, width: cw, height: chh, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: cw, height: chh))
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 0, alpha: 0.8)); ctx.setLineWidth(1)
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: NSColor.yellow, .backgroundColor: NSColor.black]
    let ns = NSGraphicsContext(cgContext: ctx, flipped: false); NSGraphicsContext.current = ns
    var gx = ((x0 + step - 1) / step) * step
    while gx < x0 + cw { let lx = CGFloat(gx - x0); ctx.move(to: CGPoint(x: lx, y: 0)); ctx.addLine(to: CGPoint(x: lx, y: CGFloat(chh))); ctx.strokePath(); ("\(gx)" as NSString).draw(at: NSPoint(x: lx + 2, y: CGFloat(chh) - 14), withAttributes: attrs); gx += step }
    var gy = ((y0 + step - 1) / step) * step
    while gy < y0 + chh { let ly = CGFloat(chh) - CGFloat(gy - y0); ctx.move(to: CGPoint(x: 0, y: ly)); ctx.addLine(to: CGPoint(x: CGFloat(cw), y: ly)); ctx.strokePath(); ("\(gy)" as NSString).draw(at: NSPoint(x: 2, y: ly + 2), withAttributes: attrs); gy += step }
    saveJPG(ctx.makeImage()!, CommandLine.arguments[3])
case "screen": // cantos de uma tela uniforme: args imagem, seedX, seedY, tolerância(0-255)
    let img = load(CommandLine.arguments[2]); let sx = Int(CommandLine.arguments[3])!, sy = Int(CommandLine.arguments[4])!, tol = Int(CommandLine.arguments[5])!
    let (d, w, h) = pixels(img)
    func px(_ x: Int, _ y: Int) -> (Int, Int, Int) { let i = (y*w+x)*4; return (Int(d[i]), Int(d[i+1]), Int(d[i+2])) }
    let seed = px(sx, sy)
    var seen = [Bool](repeating: false, count: w*h); var stack = [(sx, sy)]; seen[sy*w+sx] = true
    var pts: [(Int, Int)] = []
    while let (x, y) = stack.popLast() {
        pts.append((x, y))
        for (nx, ny) in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)] where nx >= 0 && ny >= 0 && nx < w && ny < h && !seen[ny*w+nx] {
            let p = px(nx, ny)
            if abs(p.0-seed.0) <= tol && abs(p.1-seed.1) <= tol && abs(p.2-seed.2) <= tol { seen[ny*w+nx] = true; stack.append((nx, ny)) }
        }
    }
    // cantos: extremos de (x+y), (x−y), (−x+y), (−x−y) — funciona para quadriláteros pouco rotacionados
    func ext(_ f: ((Int, Int)) -> Int) -> (Int, Int) { pts.max(by: { f($0) < f($1) })! }
    let tl = ext { -$0.0 - $0.1 }, tr = ext { $0.0 - $0.1 }, bl = ext { -$0.0 + $0.1 }, br = ext { $0.0 + $0.1 }
    let W = Double(w), H = Double(h)
    print(String(format: "area=%d TL(%.4f, %.4f) TR(%.4f, %.4f) BL(%.4f, %.4f) BR(%.4f, %.4f)", pts.count, Double(tl.0)/W, Double(tl.1)/H, Double(tr.0)/W, Double(tr.1)/H, Double(bl.0)/W, Double(bl.1)/H, Double(br.0)/W, Double(br.1)/H))
    // Ajuste por retas: cantos arredondados e entalhes encolhem os extremos. Para cada borda do
    // quadrilátero inicial, os pontos do contorno perto dela (faixa de 8 px, 15–85 % do comprimento)
    // são ajustados por uma reta (PCA) e os cantos ficam na interseção das retas vizinhas.
    var inRegion = [Bool](repeating: false, count: w*h); for (x, y) in pts { inRegion[y*w+x] = true }
    var boundary: [(Double, Double)] = []
    for (x, y) in pts {
        for (nx, ny) in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)] where nx < 0 || ny < 0 || nx >= w || ny >= h || !inRegion[ny*w+nx] {
            boundary.append((Double(x) + 0.5, Double(y) + 0.5)); break
        }
    }
    func fitLine(_ P: (Int, Int), _ Q: (Int, Int)) -> (Double, Double, Double)? { // reta a·x + b·y = c
        let px = Double(P.0), py = Double(P.1), dx = Double(Q.0) - px, dy = Double(Q.1) - py
        let len = (dx*dx + dy*dy).squareRoot(); let ux = dx/len, uy = dy/len, nx = -uy, ny = ux
        let sel = boundary.filter { p in let t = ((p.0-px)*ux + (p.1-py)*uy)/len; let d = (p.0-px)*nx + (p.1-py)*ny; return t > 0.15 && t < 0.85 && abs(d) < 8 }
        guard sel.count > 20 else { return nil }
        let mx = sel.map { $0.0 }.reduce(0, +)/Double(sel.count), my = sel.map { $0.1 }.reduce(0, +)/Double(sel.count)
        var sxx = 0.0, sxy = 0.0, syy = 0.0
        for p in sel { sxx += (p.0-mx)*(p.0-mx); sxy += (p.0-mx)*(p.1-my); syy += (p.1-my)*(p.1-my) }
        // direção principal (autovetor maior da covariância)
        let theta = 0.5 * atan2(2*sxy, sxx - syy); let dxx = cos(theta), dyy = sin(theta)
        let a = -dyy, b = dxx; return (a, b, a*mx + b*my)
    }
    func cross(_ l1: (Double, Double, Double), _ l2: (Double, Double, Double)) -> (Double, Double) {
        let det = l1.0*l2.1 - l2.0*l1.1; return ((l1.2*l2.1 - l2.2*l1.1)/det, (l1.0*l2.2 - l2.0*l1.2)/det)
    }
    if let lt = fitLine(tl, tr), let lr = fitLine(tr, br), let lb = fitLine(bl, br), let ll = fitLine(tl, bl) {
        let ftl = cross(ll, lt), ftr = cross(lr, lt), fbl = cross(ll, lb), fbr = cross(lr, lb)
        print(String(format: "fit    TL(%.4f, %.4f) TR(%.4f, %.4f) BL(%.4f, %.4f) BR(%.4f, %.4f)", ftl.0/W, ftl.1/H, ftr.0/W, ftr.1/H, fbl.0/W, fbl.1/H, fbr.0/W, fbr.1/H))
    } else { print("fit    (contorno insuficiente em alguma borda)") }
default: break
}

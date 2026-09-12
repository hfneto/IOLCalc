import Foundation
import Testing
@testable import IOLCore

/// Valores gerados pelo JavaScript original do módulo tórico (docs/toric-generator.js no jsc).
struct ToricGolden: Decodable {
    struct Input: Decodable {
        let mode: String
        let k1: Double?, k2: Double?, kaxis: Double?, tkcyl: Double?, tkaxis: Double?
        let sia: Double?, siaAxis: Double?, iolcyl: Double?, align: Double?, ratio: Double?
    }
    struct Output: Decodable {
        let taMag: Double, taAxis: Double, cc: Double, resMag: Double, resAxis: Double, resAligned: Double, mis: Double
        let lost: Int
        let sugg: [String: [Double]]
    }
    struct Case: Decodable { let input: Input; let out: Output }
    struct Ratio: Decodable { let AL: Double, Km: Double, A: Double, P: Double, cyl: Double; let ratio: Double? }
    let cases: [Case]
    let ratios: [Ratio]
    let ak: [[Double]]

    static func load() throws -> ToricGolden {
        let url = try #require(Bundle.module.url(forResource: "toric", withExtension: "json"))
        return try JSONDecoder().decode(ToricGolden.self, from: Data(contentsOf: url))
    }

    static func input(_ i: Input) -> ToricInput {
        var t = ToricInput()
        t.model = CornealAstigmatismModel(rawValue: i.mode)!
        t.k1 = i.k1; t.k2 = i.k2
        t.kAxis = i.kaxis ?? 90
        t.totalCylinder = i.tkcyl ?? 0
        t.totalAxis = i.tkaxis ?? 90
        t.sia = i.sia ?? 0
        t.siaAxis = i.siaAxis ?? 180
        t.iolCylinder = i.iolcyl ?? 0
        t.iolAxis = i.align ?? 90
        t.ratio = i.ratio ?? 1.46
        return t
    }
}

@Suite("Módulo tórico vs. JavaScript original")
struct ToricGoldenTests {
    let golden = try! ToricGolden.load()
    let tol = 1e-9

    @Test("Astigmatismo total, LIO no plano corneano, residual, desalinhamento e sugestão por plataforma")
    func plans() {
        #expect(golden.cases.count > 300)
        for c in golden.cases {
            let plan = ToricPlanner.plan(ToricGolden.input(c.input))
            let tag = "\(c.input.mode) k=\(c.input.k1 ?? .nan)/\(c.input.k2 ?? .nan)@\(c.input.kaxis ?? 90) sia=\(c.input.sia ?? 0)@\(c.input.siaAxis ?? 180) iol=\(c.input.iolcyl ?? 0)@\(c.input.align ?? 90) r=\(c.input.ratio ?? 1.46)"
            #expect(abs(plan.totalMagnitude - c.out.taMag) < tol, "taMag \(tag)")
            #expect(abs(plan.totalAxis - c.out.taAxis) < tol, "taAxis \(tag)")
            #expect(abs(plan.iolAtCornealPlane - c.out.cc) < tol, "cc \(tag)")
            #expect(abs(plan.residualMagnitude - c.out.resMag) < tol, "resMag \(tag)")
            #expect(abs(plan.residualAxis - c.out.resAxis) < tol, "resAxis \(tag)")
            #expect(abs(plan.residualIfAligned - c.out.resAligned) < tol, "resAligned \(tag)")
            #expect(abs(plan.misalignment - c.out.mis) < tol, "mis \(tag)")
            #expect(plan.lostCorrectionPercent == c.out.lost, "lost \(tag)")
            for (id, expected) in c.out.sugg {
                let s = ToricPlanner.suggestion(for: plan, platform: ToricPlatform.platform(id: id))
                #expect(s.cylinder == expected[0] && s.axis == expected[1], "sugestão \(id) \(tag): \(s) ≠ \(expected)")
            }
        }
    }

    @Test("Razão de toricidade pela ELP do olho (SRK/T)")
    func toricityRatio() {
        for r in golden.ratios {
            let eye = EyeBiometry(axialLength: r.AL, keratometry: r.Km)
            let got = ToricPlanner.toricityRatio(eye: eye, effectiveA: r.A, implantedPower: r.P, iolCylinder: r.cyl)
            switch (got, r.ratio) {
            case let (g?, e?): #expect(abs(g - e) < tol, "AL \(r.AL): \(g) ≠ \(e)")
            case (nil, nil): break
            default: Issue.record("AL \(r.AL): \(String(describing: got)) ≠ \(String(describing: r.ratio))")
            }
        }
        #expect(golden.ratios.contains { $0.ratio != nil })
    }

    @Test("Abulafia-Koch: WTR 1,0 D @ 90° → ≈0,42 D; ATR 1,0 D @ 180° → ≈1,43 D; córnea esférica → 0,508 D ATR")
    func abulafiaKoch() {
        for row in golden.ak {
            let v = ToricRegression.abulafiaKoch(AstigmatismVector(magnitude: row[0], axis: row[1]))
            #expect(abs(v.magnitude - row[2]) < tol && abs(v.axis - row[3]) < tol)
        }
        let wtr = ToricRegression.abulafiaKoch(AstigmatismVector(magnitude: 1, axis: 90))
        #expect(abs(wtr.magnitude - 0.418) < 0.01 && abs(wtr.axis - 89.4) < 1.5)
        #expect(abs(ToricRegression.abulafiaKoch(AstigmatismVector(magnitude: 1, axis: 180)).magnitude - 1.434) < 0.01)
        #expect(abs(ToricRegression.abulafiaKoch(.zero).magnitude - 0.508) < 0.01)
    }

    @Test("Plataformas, fabricante → plataforma e limiares")
    func platforms() {
        #expect(ToricPlatform.all.count == 6)
        #expect(ToricPlatform.platform(id: "zeiss").steps.count == 23 && ToricPlatform.platform(id: "zeiss").steps.last == 12.0)
        #expect(ToricPlatform.platform(id: "generic").steps.first == 0.75 && ToricPlatform.platform(id: "generic").steps.last == 6.5)
        #expect(ToricPlatform.id(forManufacturer: "J&J Vision") == "jj")
        #expect(ToricPlatform.id(forManufacturer: "PhysIOL / BVI") == "generic")
        #expect(ToricPlatform.platform(id: "nada").id == "alcon")
        var i = ToricInput(); i.k1 = 43; i.k2 = 43.5; i.sia = 0
        #expect(ToricPlanner.plan(i).belowToricThreshold)
        i.k2 = 45
        #expect(!ToricPlanner.plan(i).belowToricThreshold)
    }
}

@Suite("Simulação visual: constantes e escalas da versão web")
struct SimulationTests {
    @Test("σ do desfoque, tamanho físico, penalidade noturna e arrasto do astigmatismo")
    func scales() {
        #expect(VisualSimulation.blurSigma(logMAR: 0) == 0)
        #expect(VisualSimulation.blurSigma(logMAR: -0.1) == 0)
        #expect(abs(VisualSimulation.blurSigma(logMAR: 0.3) - 0.6 * (pow(10, 0.3) - 1) * 4) < 1e-12)
        #expect(VisualSimulation.blurSigma(logMAR: 2) == 40)
        #expect(abs(VisualSimulation.pixels(forMillimetres: 5.3, at: 40) - (5.3 / 400) * 3437.75 * 4) < 1e-9)
        #expect(VisualSimulation.acuity(0.1, night: false) == 0.1)
        #expect(abs(VisualSimulation.acuity(0.1, night: true) - 0.18) < 1e-12)
        #expect(VisualSimulation.acuity(0.9, night: true) == 0.85)
        #expect(VisualSimulation.directionalBlur(cylinder: 1) == 20)
        #expect(VisualSimulation.directionalBlur(cylinder: 10) == 120)
        #expect(VisualSimulation.haloIntensity(dysphotopsia: 3, mode: 1) == 1)
        #expect(VisualSimulation.contrast(dysphotopsia: 3, night: true) == 0.66)
        #expect(VisualSimulation.tiles.map(\.defocus) == [-2.5, -1.43, -1.33, 0])
    }
}

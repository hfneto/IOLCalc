import Foundation
import Testing
@testable import IOLCore

/// Valores gerados pelo JavaScript original (docs/golden-generator.js rodado no JavaScriptCore).
/// Qualquer divergência acima de 1e-9 D indica que o porte deixou de ser fiel.
struct Golden: Decodable {
    struct Row: Decodable {
        let AL: Double, K: Double, ACD: Double, LT: Double, A: Double, R: Double
        let p: [String: Double]
        let pred: Double
    }
    let eyes: [Row]
    let castropH: [String: Double]
    let haigisA0: [String: Double]
    let sample: [[Double]]
    let bino: [[Double]]
    let stereo: [Int]
    let jaeger: [String]

    static func load() throws -> Golden {
        let url = try #require(Bundle.module.url(forResource: "golden", withExtension: "json"))
        return try JSONDecoder().decode(Golden.self, from: Data(contentsOf: url))
    }
}

@Suite("Motor de fórmulas vs. JavaScript original")
struct GoldenFormulaTests {
    let golden = try! Golden.load()
    let tolerance = 1e-9

    @Test("Poder da LIO em 54 combinações olho × constante A × alvo")
    func powers() {
        for row in golden.eyes {
            let eye = EyeBiometry(axialLength: row.AL, keratometry: row.K, acd: row.ACD, lensThickness: row.LT)
            for (name, expected) in row.p {
                let key = try! #require(FormulaKey(rawValue: name))
                let got = IOLFormulas.power(key, eye: eye, aConstant: row.A, target: row.R)
                #expect(abs(got - expected) < tolerance, "\(name) AL=\(row.AL) A=\(row.A) R=\(row.R): \(got) ≠ \(expected)")
            }
            #expect(Set(row.p.keys) == Set(IOLFormulas.activeFormulas(axialLength: row.AL).map(\.rawValue)))
        }
    }

    @Test("Refração prevista por inversão do SRK/T (poder 20,5 D)")
    func predictedRefraction() {
        for row in golden.eyes {
            let eye = EyeBiometry(axialLength: row.AL, keratometry: row.K, acd: row.ACD, lensThickness: row.LT)
            let got = IOLFormulas.predictedRefraction(.srkt, eye: eye, aConstant: row.A, implantedPower: 20.5)
            #expect(abs(got - row.pred) < tolerance)
        }
    }

    @Test("Calibrações Castrop H e Haigis a0")
    func calibrations() {
        for (a, expected) in golden.castropH {
            #expect(abs(IOLFormulas.castropH(aConstant: Double(a)!) - expected) < tolerance)
        }
        for (a, expected) in golden.haigisA0 {
            #expect(abs(IOLFormulas.haigisA0(aConstant: Double(a)!) - expected) < tolerance)
        }
    }

    @Test("Curva de defocus, AV monocular, somação binocular, estereopsia e Jaeger")
    func vision() {
        let curve = [0.18, 0.05, -0.04, 0.03, 0.13, 0.24, 0.38, 0.52, 0.65]
        for s in golden.sample {
            #expect(abs(DefocusModel.sampleCurve(curve, at: s[0]) - s[1]) < tolerance)
            #expect(abs(DefocusModel.monocularVA(curve: curve, residual: -0.25, defocus: s[0], cylinder: 0.75) - s[2]) < tolerance)
        }
        for b in golden.bino {
            #expect(abs(DefocusModel.binocularCombine(b[0], b[1]) - b[2]) < tolerance)
        }
        #expect(Stereopsis.compute(.monofocal, .monofocal, seA: 0, seB: 0) == golden.stereo[0])
        #expect(Stereopsis.compute(.edof, .trifocal, seA: -0.5, seB: 0.4) == golden.stereo[1])
        #expect(Stereopsis.compute(.monofocal, .trifocal, seA: 0, seB: -1.6) == golden.stereo[2])
        #expect([0.0, 0.13, 0.3, 0.5, 0.9].map(DefocusModel.jaeger(fromLogMAR:)) == golden.jaeger)
    }
}

@Suite("Autoteste clínico (snapshots da versão web, A = 119,0)")
struct SelfTestSnapshots {
    static let snapshots: [(EyeBiometry, [FormulaKey: Double])] = [
        (EyeBiometry(axialLength: 23.5, keratometry: 43.5, acd: 3.37, lensThickness: 4.7),
         [.srkt: 21.29, .t2: 21.32, .holladay1: 21.27, .hofferQ: 21.25, .haigis: 21.29, .castrop: 21.29]),
        (EyeBiometry(axialLength: 21.0, keratometry: 46.0, acd: 2.80, lensThickness: 4.9),
         [.srkt: 27.49, .t2: 27.65, .holladay1: 27.57, .hofferQ: 27.88, .haigis: 27.65, .castrop: 27.39]),
        (EyeBiometry(axialLength: 27.5, keratometry: 42.0, acd: 3.60, lensThickness: 4.4),
         [.srkt: 11.08, .t2: 11.50, .holladay1: 10.61, .holladay1WK: 11.57, .hofferQ: 10.90, .haigis: 11.00, .castrop: 10.96]),
        (EyeBiometry(axialLength: 30.0, keratometry: 43.0, acd: 3.80, lensThickness: 4.2),
         [.srkt: 3.40, .t2: 3.57, .holladay1: 2.77, .holladay1WK: 4.66, .hofferQ: 2.61, .haigis: 3.49, .castrop: 3.82]),
    ]

    @Test("Snapshots dentro de 0,015 D")
    func snapshots() {
        for (eye, expected) in Self.snapshots {
            for (key, value) in expected {
                let got = IOLFormulas.power(key, eye: eye, aConstant: 119.0, target: 0)
                #expect(abs(got - value) <= 0.015, "\(key.rawValue) AL=\(eye.axialLength): \(got)")
            }
        }
    }

    @Test("Invariantes: concordância no olho padrão, Castrop calibrada, inversão, Wang-Koch")
    func invariants() {
        let eye = IOLFormulas.standardEye
        let powers = IOLFormulas.activeFormulas(axialLength: eye.axialLength).map { IOLFormulas.power($0, eye: eye, aConstant: 119.0, target: 0) }
        #expect(powers.max()! - powers.min()! <= 0.15)
        #expect(abs(IOLFormulas.power(.castrop, eye: eye, aConstant: 119.0, target: 0) - IOLFormulas.power(.srkt, eye: eye, aConstant: 119.0, target: 0)) <= 0.01)
        let p5 = IOLFormulas.power(.srkt, eye: eye, aConstant: 119.0, target: -0.5)
        #expect(abs(IOLFormulas.predictedRefraction(.srkt, eye: eye, aConstant: 119.0, implantedPower: p5) - (-0.5)) <= 0.01)
        let long = EyeBiometry(axialLength: 30, keratometry: 43)
        #expect(IOLFormulas.power(.holladay1WK, eye: long, aConstant: 119.0, target: 0) > IOLFormulas.power(.holladay1, eye: long, aConstant: 119.0, target: 0))
        #expect(IOLFormulas.activeFormulas(axialLength: 23.5).contains(.holladay1WK) == false)
        #expect(IOLFormulas.recommendedFormulas(axialLength: 21) == [.hofferQ, .haigis, .castrop])
    }

    @Test("Castrop com paquimetria medida (valores do JS: 541, ausente e 650 µm)")
    func castropCCT() {
        let f: (Double?) -> Double = { IOLFormulas.castrop(axialLength: 23.62, keratometry: 43.675, aConstant: 119.1, target: 0, acd: 3.21, lensThickness: 4.52, cctMicrons: $0) }
        #expect(abs(f(541) - 20.272993615102237) < 1e-9)
        #expect(abs(f(nil) - 20.29365986600856) < 1e-9)
        #expect(abs(f(650) - 20.218168639809953) < 1e-9)
        #expect(f(500) == f(nil))
    }

    @Test("Catálogo: 20 lentes, ids únicos, 9 pontos de defocus")
    func catalog() {
        #expect(LensCatalog.all.count == 20)
        #expect(LensCatalog.byID.count == 20)
        #expect(LensCatalog.all.allSatisfy { $0.defocusValues.count == DefocusModel.defocusAxis.count })
        #expect(LensCatalog.lens(id: "panoptix")?.aConstant == 119.1)
    }
}

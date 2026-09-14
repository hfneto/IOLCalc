import SwiftUI
import IOLCore

// MARK: - 4 · Calculadoras oficiais

/// Abre as calculadoras oficiais numa sheet, com a biometria injetada nos campos reconhecidos,
/// e copia a biometria como texto para colar em qualquer outra.
struct CalculatorsSection: View {
    let model: CalculatorModel
    @State private var external: ExternalCalculator?
    @State private var copied = false

    var body: some View {
        SectionCard(title: "4 · Calculadoras oficiais", trailing: AnyView(
            PillButton(title: copied ? "Copiado ✓" : "Copiar biometria", systemImage: "doc.on.doc") {
                Clipboard.copy(model.biometrySummaryText())
                copied = true
                Task { try? await Task.sleep(for: .seconds(2)); copied = false }
            }
        )) {
            MutedText("Cada botão abre a calculadora dentro do app e preenche AL, K1, K2, ACD, LT, WTW, constante A e alvo dos dois olhos nos campos que reconhecer (confira sempre). Se um site não aceitar o preenchimento automático, use \"Copiar biometria\" e cole à mão.", size: 12.5)
            FlowButtons {
                ForEach(OfficialCalculator.all) { calc in
                    PillButton(title: calc.name + " ⇢ preencher") { external = ExternalCalculator(calc, dataJSON: model.biometryJSON()) }
                }
            }
            MutedText("As fórmulas modernas (Barrett, Kane, EVO, Hoffer QST, Hill-RBF, Lucena) não são publicadas; por isso ficam nos sites oficiais. Use-as para conferir a sugestão da seção 3, sobretudo em olhos atípicos.", size: 11.5)
        }
        .sheet(item: $external) { CalculatorFillSheet(calc: $0) }
    }
}

/// Botões em linha, quebrando para a linha seguinte quando falta largura.
struct FlowButtons<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        FlowLayout(spacing: 8) { content }
    }
}

/// Layout de fluxo simples (esquerda → direita, depois quebra). Um item mais largo que o contêiner
/// recebe a largura do contêiner e quebra o texto em vez de estourar a borda.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    private func fit(_ s: LayoutSubview, in width: CGFloat) -> (CGSize, ProposedViewSize) {
        let sz = s.sizeThatFits(.unspecified)
        guard width.isFinite, sz.width > width else { return (sz, .unspecified) }
        let p = ProposedViewSize(width: width, height: nil)
        return (s.sizeThatFits(p), p)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let (sz, _) = fit(s, in: width)
            if x > 0, x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height); maxX = max(maxX, x - spacing)
        }
        return CGSize(width: width == .infinity ? maxX : width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let (sz, p) = fit(s, in: bounds.width)
            if x > bounds.minX, x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: p)
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}

enum Clipboard {
    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

extension CalculatorModel {
    /// Mesmo formato do `bioJSON()` da versão web (números com ponto, `null` quando vazio).
    func biometryJSON() -> String {
        func eye(_ e: Eye) -> [String: Any] {
            let f = self[e]
            func n(_ s: String) -> Any { Num.parse(s).map { $0 as Any } ?? NSNull() }
            return ["AL": n(f.al), "K1": n(f.k1), "K2": n(f.k2), "ACD": n(f.acd), "LT": n(f.lt), "WTW": n(f.wtw), "CCT": n(f.cct),
                    "TK1": n(f.tk1), "TK2": n(f.tk2), "A": n(f.aConstant), "TGT": n(f.target)]
        }
        let obj: [String: Any] = ["v": 1, "OD": eye(.od), "OE": eye(.oe)]
        let data = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    /// Texto para colar: "OD: AL 23,62 | K1 … " por olho.
    func biometrySummaryText() -> String {
        func line(_ e: Eye) -> String {
            let f = self[e]
            let parts = [("AL", f.al), ("K1", f.k1), ("K2", f.k2), ("ACD", f.acd), ("LT", f.lt), ("WTW", f.wtw), ("CCT", f.cct), ("A", f.aConstant), ("alvo", f.target)]
                .map { pair in "\(pair.0) \(Num.parse(pair.1) == nil ? "—" : pair.1)" }
            return "\(e.rawValue): " + parts.joined(separator: " | ")
        }
        let name = patientName.trimmingCharacters(in: .whitespacesAndNewlines)
        return (name.isEmpty ? "Biometria" : "Biometria — \(name)") + "\n" + line(.od) + "\n" + line(.oe)
    }
}

import SwiftUI
import IOLCore

/// Paleta da calculadora web (`:root` do index.html), para a tela nativa ficar idêntica.
enum Theme {
    static let bg = Color(hex: 0xf1f5f9)
    static let card = Color.white
    static let ink = Color(hex: 0x0f172a)
    static let muted = Color(hex: 0x64748b)
    static let line = Color(hex: 0xe2e8f0)
    static let brand = Color(hex: 0x2563eb)
    static let od = Color(hex: 0xdc2626)
    static let oe = Color(hex: 0x2563eb)
    static let soft = Color(hex: 0xf8fafc)
    static let okBg = Color(hex: 0xecfdf5)
    static let okBorder = Color(hex: 0xa7f3d0)
    static let okInk = Color(hex: 0x065f46)
    static let errBg = Color(hex: 0xfef2f2)
    static let errBorder = Color(hex: 0xfecaca)
    static let errInk = Color(hex: 0x991b1b)
    static let chipBg = Color(hex: 0xe2e8f0)
    static let chipInk = Color(hex: 0x475569)
    static let bino = Color(hex: 0x7c3aed)
    static let warn = Color(hex: 0xd97706)

    static func accent(_ eye: Eye) -> Color { eye == .od ? od : oe }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}

// MARK: - Largura compacta (iPhone na vertical)

/// `true` quando a largura é compacta (iPhone em pé). No macOS é sempre `false`; em DEBUG o
/// argumento `-iol_force_compact YES` força `true` para renderizar o layout de iPhone no Mac.
struct CompactWidthKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    var isCompactWidth: Bool {
        get { self[CompactWidthKey.self] }
        set { self[CompactWidthKey.self] = newValue }
    }
}

/// Lê o size class da plataforma e publica `isCompactWidth` para toda a subárvore.
struct CompactWidthProvider<Content: View>: View {
    @ViewBuilder let content: Content
    /// Abaixo desta largura a página de duas colunas não cabe (iPad na vertical tem 834 pt; a página
    /// foi desenhada para ≥ 1100): usa-se o layout de coluna única do iPhone.
    static var threshold: CGFloat { 1000 }
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var forced: Bool { sizeClass == .compact }
    #else
    private var forced: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "iol_force_compact")
        #else
        false
        #endif
    }
    #endif
    var body: some View {
        GeometryReader { g in
            content.environment(\.isCompactWidth, forced || g.size.width < Self.threshold)
        }
    }
}

/// Largura fixa (tamanho ideal) só quando há espaço; na largura compacta o controle pode encolher.
struct CompactFixedSize: ViewModifier {
    @Environment(\.isCompactWidth) private var compact
    func body(content: Content) -> some View { content.fixedSize(horizontal: !compact, vertical: false) }
}

extension View {
    func compactFixedSize() -> some View { modifier(CompactFixedSize()) }
}

/// HStack com espaço; VStack alinhada à esquerda na largura compacta.
struct AdaptiveHStack<Content: View>: View {
    var alignment: VerticalAlignment = .center
    var spacing: CGFloat = 8
    @ViewBuilder let content: Content
    @Environment(\.isCompactWidth) private var compact
    var body: some View {
        if compact { VStack(alignment: .leading, spacing: spacing) { content } } else { HStack(alignment: alignment, spacing: spacing) { content } }
    }
}

// MARK: - Componentes

/// Cartão branco de seção (raio 14, borda cinza).
struct SectionCard<Content: View>: View {
    let title: String
    var trailing: AnyView? = nil
    @ViewBuilder var content: Content

    @Environment(\.isCompactWidth) private var compact

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if compact {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                if let trailing { trailing.frame(maxWidth: .infinity, alignment: .leading) }
            } else {
                HStack(spacing: 12) {
                    Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                    Spacer()
                    trailing
                }
            }
            content
        }
        .padding(EdgeInsets(top: compact ? 14 : 18, leading: compact ? 14 : 20, bottom: compact ? 14 : 18, trailing: compact ? 14 : 20))
        // Sem `clipShape` no cartão: no macOS 26 os controles AppKit (menus, caixas de seleção,
        // setas dos DisclosureGroup) ficavam quase transparentes dentro de um contêiner recortado.
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
    }
}

/// Cartão de um olho: fundo suave, faixa superior na cor do olho e etiqueta OD/OE.
struct EyeCard<Content: View>: View {
    let eye: Eye
    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title ?? eye.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                EyeBadge(eye: eye)
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.soft, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.accent(eye)).frame(height: 3).clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))
        }
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
    }
}

struct EyeBadge: View {
    let eye: Eye
    var body: some View {
        Text(eye.rawValue).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(Capsule().fill(Theme.accent(eye)))
    }
}

struct Chip: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11)).foregroundStyle(Theme.chipInk)
            .padding(.horizontal, 7).padding(.vertical, 1)
            .background(Capsule().fill(Theme.chipBg))
    }
}

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
    }
}

/// Campo numérico rotulado (aceita vírgula ou ponto).
struct NumberField: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var highlighted = false
    /// Botão "?" ao lado do rótulo.
    var help: HelpTopic? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                FieldLabel(text: label)
                if let help { HelpButton(topic: help) }
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 9).padding(.vertical, 7)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(highlighted ? Theme.brand : Theme.line))
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                #endif
        }
    }
}

struct MutedText: View {
    let text: String
    var size: CGFloat = 12
    init(_ text: String, size: CGFloat = 12) { self.text = text; self.size = size }
    var body: some View {
        Text(text).font(.system(size: size)).foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true) // quebra linha em vez de truncar
    }
}

/// Botão azul preenchido (primário) ou branco com texto azul (fantasma).
struct PillButton: View {
    let title: String
    var systemImage: String? = nil
    var primary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(primary ? .white : Theme.brand)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(primary ? Theme.brand : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(primary ? Theme.brand : Theme.line))
        }
        .buttonStyle(.plain)
    }
}

/// Seletor de LIO agrupado por categoria, como o `<select>` da web. Mostra só as favoritas
/// (Configurações › Lentes), mais a lente em uso se não for favorita, e "Outra LIO…" no fim.
struct LensPicker: View {
    @Binding var selection: String
    var placeholder = "— selecione a LIO —"
    /// LIO digitada à mão em vigor (mostrada quando `selection` é `IOLLens.customID`).
    var custom: CustomLens? = nil
    /// Ação de "Outra LIO…" (catálogo completo ou constante manual); `nil` esconde a opção.
    var onOther: (() -> Void)? = nil

    private static let otherTag = "__other"
    @State private var prefs = LensPreferences.shared
    /// Recria o Picker depois de "Outra…" para o menu não ficar mostrando essa opção.
    @State private var generation = 0

    var body: some View {
        let entries = entries
        Picker("", selection: proxy) {
            Text(placeholder).tag("")
            ForEach(LensCategory.allCases) { cat in
                let lenses = entries.filter { $0.category == cat }
                if !lenses.isEmpty {
                    Section(cat.title) {
                        ForEach(lenses) { Text($0.name).tag($0.id) }
                    }
                }
            }
            if selection == IOLLens.customID, let custom {
                Section("Outra") { Text(custom.name.isEmpty ? "Outra LIO" : custom.name).tag(IOLLens.customID) }
            }
            if onOther != nil {
                Section { Text("Outra LIO…").tag(Self.otherTag) }
            }
        }
        .labelsHidden()
        .id(generation)
    }

    private var proxy: Binding<String> {
        Binding(get: { selection }, set: { new in
            if new == Self.otherTag {
                generation += 1
                onOther?()
            } else {
                selection = new
            }
        })
    }

    /// Favoritas na ordem do catálogo, mais a lente selecionada quando não é favorita.
    private var entries: [IOLLens] {
        var ids = Set(prefs.favorites)
        if !selection.isEmpty, selection != IOLLens.customID { ids.insert(selection) }
        return LensCatalog.all.filter { ids.contains($0.id) }
    }
}

/// Cartão de métrica (rótulo, valor grande, nota).
struct MetricCard: View {
    let label: String
    let value: String
    let note: String
    var background: Color = .white
    var valueSize: CGFloat = 22

    var body: some View {
        VStack(spacing: 2) {
            Text(label.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
            Text(value).font(.system(size: valueSize, weight: .heavy)).foregroundStyle(Theme.ink)
            Text(note).font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
    }
}

/// Dois cartões lado a lado quando há largura; empilhados no iPhone.
struct EyePair<Content: View>: View {
    @ViewBuilder let content: (Eye) -> Content
    @Environment(\.isCompactWidth) private var stacked

    var body: some View {
        if stacked {
            VStack(spacing: 14) { content(.od); content(.oe) }
        } else {
            HStack(alignment: .top, spacing: 14) { content(.od); content(.oe) }
        }
    }
}

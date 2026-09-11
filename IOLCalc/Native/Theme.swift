import SwiftUI

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

    static func accent(_ eye: Eye) -> Color { eye == .od ? od : oe }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}

// MARK: - Componentes

/// Cartão branco de seção (raio 14, borda cinza).
struct SectionCard<Content: View>: View {
    let title: String
    var trailing: AnyView? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                trailing
            }
            content
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20))
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
        .background(Theme.soft)
        .overlay(alignment: .top) { Rectangle().fill(Theme.accent(eye)).frame(height: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            FieldLabel(text: label)
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
    var body: some View { Text(text).font(.system(size: size)).foregroundStyle(Theme.muted) }
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

/// Dois cartões lado a lado quando há largura; empilhados no iPhone.
struct EyePair<Content: View>: View {
    @ViewBuilder let content: (Eye) -> Content
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var stacked: Bool { sizeClass == .compact }
    #else
    private let stacked = false
    #endif

    var body: some View {
        if stacked {
            VStack(spacing: 14) { content(.od); content(.oe) }
        } else {
            HStack(alignment: .top, spacing: 14) { content(.od); content(.oe) }
        }
    }
}

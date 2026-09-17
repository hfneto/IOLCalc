import SwiftUI
import IOLCore

/// "Outra LIO…": escolher qualquer lente do catálogo completo (com estrela para favoritar) ou
/// digitar nome, classe e constante A de uma lente fora do catálogo.
struct LensChooserSheet: View {
    var title = "Outra LIO"
    /// `nil` esconde a aba de constante manual (comparador).
    var initialCustom: CustomLens?
    var allowCustom = true
    var onPick: (String) -> Void
    var onCustom: (CustomLens) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var mode = 0
    @State private var search = ""
    @State private var name = ""
    @State private var category: LensCategory = .monofocal
    @State private var aText = ""
    @State private var prefs = LensPreferences.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if allowCustom {
                    Picker("", selection: $mode) {
                        Text("Catálogo completo").tag(0)
                        Text("Digitar constante").tag(1)
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
                }
                if mode == 0 { catalog } else { manual }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            }
        }
        .onAppear {
            if let c = initialCustom {
                name = c.name; category = c.category; aText = Num.fmt(c.aConstant)
            }
        }
        #if os(macOS)
        .frame(minWidth: 560, idealWidth: 620, minHeight: 560, idealHeight: 680)
        #endif
    }

    // MARK: Catálogo completo

    private var filtered: [IOLLens] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return LensCatalog.all }
        return LensCatalog.all.filter { "\($0.name) \($0.manufacturer) \($0.type)".lowercased().contains(q) }
    }

    private var catalog: some View {
        List {
            Section {
                Text("Toque na lente para usá-la neste olho. A estrela inclui a lente no seletor rápido (favoritas).")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(LensCatalog.manufacturers, id: \.self) { maker in
                let lenses = filtered.filter { $0.manufacturer == maker }
                if !lenses.isEmpty {
                    Section(maker) {
                        ForEach(lenses) { lens in
                            LensRow(lens: lens, isFavorite: prefs.isFavorite(lens.id), onStar: { prefs.toggle(lens.id) })
                                .contentShape(Rectangle())
                                .onTapGesture { onPick(lens.id); dismiss() }
                        }
                    }
                }
            }
        }
        .searchable(text: $search, placement: .automatic, prompt: "Buscar por nome, fabricante ou tipo")
        #if os(macOS)
        .listStyle(.inset)
        #endif
    }

    // MARK: Constante manual

    private var manual: some View {
        Form {
            Section {
                TextField("Nome da LIO (ex.: Tecnis ZCT300)", text: $name)
                Picker("Classe", selection: $category) {
                    ForEach(LensCategory.allCases) { Text($0.title).tag($0) }
                }
                TextField("Constante A (SRK/T, biometria óptica)", text: $aText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            } footer: {
                Text("A classe define a curva de defocus (média das lentes publicadas da classe) e o grau de halos usados nas seções 5 e 6. O poder da seção 3 depende só da constante A.")
            }
            Section {
                Button("Usar esta LIO") {
                    guard let a = Num.parse(aText) else { return }
                    onCustom(CustomLens(name: name.trimmingCharacters(in: .whitespaces), category: category, aConstant: a))
                    dismiss()
                }
                .disabled(!valid)
                if !aText.isEmpty, !valid {
                    Text("Constante A fora da faixa esperada (110–125).").font(.footnote).foregroundStyle(.red)
                }
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }

    private var valid: Bool {
        guard let a = Num.parse(aText) else { return false }
        return (110...125).contains(a)
    }
}

/// Linha do catálogo: nome, tipo, constante, nota curta e estrela de favorita.
struct LensRow: View {
    let lens: IOLLens
    let isFavorite: Bool
    let onStar: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Color(hex: UInt32(lens.colorHex.dropFirst(), radix: 16) ?? 0x64748b)).frame(width: 10, height: 10).padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(lens.name).font(.system(size: 13, weight: .semibold))
                    Chip(text: lens.type)
                    if lens.curveEstimated { Chip(text: "curva estimada") }
                }
                Text("A \(Num.fmt(lens.aConstant)) · disfotopsia \(VisualSimulation.dysphotopsiaLabels[lens.dysphotopsia])")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                if !lens.notes.isEmpty {
                    Text(lens.notes).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Button(action: onStar) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 15))
                    .foregroundStyle(isFavorite ? Theme.warn : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "Tirar das favoritas" : "Marcar como favorita")
        }
        .padding(.vertical, 2)
    }
}

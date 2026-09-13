import SwiftUI

/// Casos salvos: salvar/atualizar o planejamento atual, abrir, renomear e apagar.
struct CasesSheet: View {
    let model: CalculatorModel
    @Bindable var store: CaseStore
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: SavedCase?
    @State private var newName = ""
    @State private var toDelete: SavedCase?
    @State private var flash: String?

    private var loaded: SavedCase? { store.cases.first { $0.id == model.loadedCaseID } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                saveBar
                Divider()
                if store.cases.isEmpty {
                    MutedText("Nenhum caso salvo ainda. Preencha a biometria, escolha as lentes e toque em “Salvar caso”.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(24)
                } else {
                    list
                }
                if let err = store.loadError {
                    Text(err).font(.system(size: 12)).foregroundStyle(Theme.errInk).padding(10)
                }
            }
            .background(Theme.bg)
            .navigationTitle("Casos salvos")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
            }
            .alert("Renomear caso", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Nome", text: $newName)
                Button("Salvar") { if let c = renaming { store.rename(c, to: newName) }; renaming = nil }
                Button("Cancelar", role: .cancel) { renaming = nil }
            }
            .alert("Apagar este caso?", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })) {
                Button("Apagar", role: .destructive) { if let c = toDelete { store.delete(c) }; toDelete = nil }
                Button("Cancelar", role: .cancel) { toDelete = nil }
            } message: {
                Text(toDelete?.name ?? "")
            }
        }
        #if os(macOS)
        .frame(minWidth: 560, idealWidth: 640, minHeight: 480, idealHeight: 600)
        #endif
    }

    private var saveBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 8) {
                if let loaded {
                    PillButton(title: "Atualizar “\(loaded.name)”", systemImage: "arrow.triangle.2.circlepath", primary: true) {
                        store.update(from: model); show("Caso atualizado")
                    }
                    PillButton(title: "Salvar como novo", systemImage: "plus") {
                        store.saveNew(from: model); show("Caso salvo")
                    }
                } else {
                    PillButton(title: "Salvar caso atual", systemImage: "square.and.arrow.down", primary: true) {
                        store.saveNew(from: model); show("Caso salvo")
                    }
                }
                if let flash { Text(flash).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.okInk) }
            }
            MutedText("O caso guarda biometria, lentes, alvos, régua, astigmatismo, planejamento tórico e comparador. O nome é o do paciente; renomeie pelo menu do caso.", size: 11.5)
        }
        .padding(14)
        .background(Theme.card)
    }

    private var list: some View {
        List {
            ForEach(store.cases) { c in
                Button { store.open(c, into: model); dismiss() } label: { row(c) }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Abrir") { store.open(c, into: model); dismiss() }
                        Button("Renomear…") { newName = c.name; renaming = c }
                        Button("Apagar…", role: .destructive) { toDelete = c }
                    }
                    #if os(iOS)
                    .swipeActions {
                        Button("Apagar", role: .destructive) { toDelete = c }
                        Button("Renomear") { newName = c.name; renaming = c }.tint(Theme.brand)
                    }
                    #endif
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #endif
    }

    private func row(_ c: SavedCase) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(c.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                    if c.id == model.loadedCaseID { Chip(text: "aberto") }
                }
                MutedText("OD " + (c.summaryOD ?? "—") + " · OE " + (c.summaryOE ?? "—"))
                MutedText(Self.date(c.updatedAt) + (c.createdAt != c.updatedAt ? " (criado " + Self.date(c.createdAt) + ")" : ""), size: 11)
            }
            Spacer()
            #if os(macOS)
            Button { newName = c.name; renaming = c } label: { Image(systemName: "pencil") }.buttonStyle(.borderless).help("Renomear")
            Button { toDelete = c } label: { Image(systemName: "trash") }.buttonStyle(.borderless).foregroundStyle(Theme.od).help("Apagar")
            #endif
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func show(_ text: String) {
        flash = text
        Task { try? await Task.sleep(for: .seconds(2)); if flash == text { flash = nil } }
    }

    static func date(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f.string(from: d)
    }
}

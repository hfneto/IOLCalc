import SwiftUI
import IOLCore

/// Configurações: lentes favoritas (catálogo completo), leitura por IA (chave, Face ID, modelo fixo)
/// e a ajuda com as explicações das opções avançadas.
struct SettingsSheet: View {
    @Bindable var reader: AIReaderState
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .lenses

    enum Tab: String, CaseIterable, Identifiable {
        case lenses = "Lentes", ai = "Leitura por IA", help = "Ajuda"
        var id: String { rawValue }
        var icon: String {
            switch self { case .lenses: return "star"; case .ai: return "doc.text.viewfinder"; case .help: return "questionmark.circle" }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
                switch tab {
                case .lenses: LensSettings()
                case .ai: AISettings(reader: reader)
                case .help: HelpSettings()
                }
            }
            .navigationTitle("Configurações")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Concluir") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 640, idealWidth: 720, minHeight: 600, idealHeight: 760)
        #endif
    }
}

// MARK: - Lentes

/// Catálogo completo por fabricante com a estrela de favorita; as favoritas são as que aparecem
/// no seletor da seção 2 e no comparador.
struct LensSettings: View {
    @State private var prefs = LensPreferences.shared
    @State private var search = ""
    @State private var onlyFavorites = false

    private var filtered: [IOLLens] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return LensCatalog.all.filter { lens in
            (!onlyFavorites || prefs.isFavorite(lens.id)) &&
            (q.isEmpty || "\(lens.name) \(lens.manufacturer) \(lens.type)".lowercased().contains(q))
        }
    }

    var body: some View {
        List {
            Section {
                Text("As lentes com estrela aparecem no seletor da seção 2 e no comparador. As outras continuam disponíveis em \"Outra LIO…\". Constantes A para biometria óptica (fabricante/IOLcon; ULIB para lentes antigas); a origem está na nota de cada lente. Confira o registro Anvisa e a disponibilidade com o distribuidor.")
                    .font(.footnote).foregroundStyle(.secondary)
                HStack {
                    Toggle("Só favoritas (\(prefs.favorites.count))", isOn: $onlyFavorites)
                        #if os(macOS)
                        .toggleStyle(.checkbox)
                        #endif
                    Spacer()
                    Button("Restaurar padrão") { prefs.restoreDefaults() }.font(.footnote)
                }
            }
            ForEach(LensCatalog.manufacturers, id: \.self) { maker in
                let lenses = filtered.filter { $0.manufacturer == maker }
                if !lenses.isEmpty {
                    Section("\(maker) · \(lenses.count)") {
                        ForEach(lenses) { lens in
                            LensRow(lens: lens, isFavorite: prefs.isFavorite(lens.id), onStar: { prefs.toggle(lens.id) })
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
}

// MARK: - Leitura por IA

struct AISettings: View {
    @Bindable var reader: AIReaderState
    @AppStorage("iol_lock_enabled") private var lockEnabled = true
    @State private var showKey = false
    @State private var confirmRemove = false

    var body: some View {
        Form {
            Section("Chave da API da Anthropic") {
                LabeledContent("Estado", value: reader.hasKey ? "configurada · leitura por IA ativa" : "sem chave · leitura por IA desativada")
                Button(reader.hasKey ? "Trocar chave…" : "Configurar chave…") { showKey = true }
                if reader.hasKey {
                    Button("Remover chave deste Apple ID", role: .destructive) { confirmRemove = true }
                }
            }
            Section("Segurança") {
                Toggle("Pedir \(AppLock.methodName) ao abrir o app", isOn: $lockEnabled)
                Text("A chave fica no Keychain, sincronizada pelo iCloud Keychain para os seus outros aparelhos. Com a trava ligada, o app pede \(AppLock.methodName) ao abrir e antes de usar a chave.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Modelo") {
                LabeledContent("Modelo de leitura", value: "\(AIReader.defaultModelTitle) (\(AIReader.defaultModel))")
                Text("Fixo: o laudo (foto ou PDF) vai direto do app para a API e volta como JSON com os campos por olho. Confira sempre os valores lidos com o laudo aberto ao lado.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .sheet(isPresented: $showKey) {
            APIKeyView(isChanging: reader.hasKey,
                       onSave: { _ in reader.refreshKey(); showKey = false },
                       onSkip: { showKey = false })
                #if os(macOS)
                .frame(minWidth: 480, minHeight: 520)
                #endif
        }
        .confirmationDialog("Remover a chave da API?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remover", role: .destructive) { APIKeyStore.clear(); reader.refreshKey() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("A leitura por IA fica desativada em todos os aparelhos até você colar a chave de novo.")
        }
    }
}

// MARK: - Ajuda

struct HelpSettings: View {
    var body: some View {
        List {
            Section {
                Text("As mesmas explicações aparecem no botão \"?\" ao lado de cada opção da calculadora.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(HelpTopic.allCases) { topic in
                DisclosureGroup {
                    HelpTopicView(topic: topic, showTitle: false).padding(.vertical, 4)
                } label: {
                    Text(topic.title).font(.system(size: 13.5, weight: .semibold))
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #endif
    }
}

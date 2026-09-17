import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Botão "Ler laudo com IA" e tudo que ele precisa: escolha do arquivo (Mac: arquivos;
/// iPhone: câmera, fotos ou arquivos), mensagem de estado e a gaveta "avançado"
/// (estado da chave da API; o modelo é fixo). Vive dentro da seção 1.
struct AIReadControls: View {
    let model: CalculatorModel
    @Bindable var reader: AIReaderState

    @State private var showFiles = false
    @State private var showKey = false
    #if os(iOS)
    @State private var showSources = false
    @State private var showPhotos = false
    @State private var showCamera = false
    @State private var photoItems: [PhotosPickerItem] = []
    #endif

    var body: some View {
        // O conteúdo visível é só o botão; sheets/pickers ficam anexados a ele.
        PillButton(title: reader.busy ? "Lendo…" : "Ler laudo com IA", systemImage: "doc.text.viewfinder", primary: true) {
            #if os(iOS)
            showSources = true
            #else
            showFiles = true
            #endif
        }
        .disabled(reader.busy)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            let files = urls.compactMap(Self.load)
            Task { await reader.read(files, into: model) }
        }
        .sheet(isPresented: $showKey) {
            APIKeyView(isChanging: reader.hasKey,
                       onSave: { _ in reader.refreshKey(); showKey = false },
                       onSkip: { showKey = false })
                .keySheetFrame()
        }
        #if os(iOS)
        .confirmationDialog("Ler laudo de biometria", isPresented: $showSources, titleVisibility: .visible) {
            if VNDocumentCameraViewController.isSupported {
                Button("Digitalizar com a câmera") { showCamera = true }
            }
            Button("Escolher nas Fotos") { showPhotos = true }
            Button("Escolher arquivo ou PDF") { showFiles = true }
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItems, maxSelectionCount: 6, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            photoItems = []
            Task {
                var files: [PickedFile] = []
                for (i, item) in items.enumerated() {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        files.append(PickedFile(data: data, name: "foto\(i + 1)", type: item.supportedContentTypes.first))
                    }
                }
                await reader.read(files, into: model)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            DocumentScanner { images in
                showCamera = false
                let files = images.enumerated().compactMap { i, img in
                    img.jpegData(compressionQuality: 0.92).map { PickedFile(data: $0, name: "pagina\(i + 1).jpg", type: .jpeg) }
                }
                guard !files.isEmpty else { return }
                Task { await reader.read(files, into: model) }
            }
            .ignoresSafeArea()
        }
        #endif
    }

    /// Lê um arquivo escolhido pelo usuário (acesso com escopo de segurança no sandbox).
    static func load(_ url: URL) -> PickedFile? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return PickedFile(data: data, name: url.lastPathComponent, type: UTType(filenameExtension: url.pathExtension))
    }

    /// Gaveta "Leitura por IA · avançado": estado da chave e modelo (fixo). O resto fica em Configurações.
    struct Advanced: View {
        @Bindable var reader: AIReaderState
        @State private var open = false
        @State private var showKey = false

        var body: some View {
            DisclosureGroup(isExpanded: $open) {
                FlowLayout(spacing: 12) {
                    MutedText(reader.hasKey ? "chave da API configurada · leitura por IA ativa" : "sem chave da API · leitura por IA desativada")
                    PillButton(title: reader.hasKey ? "Trocar chave da API" : "Configurar chave") { showKey = true }
                    MutedText("modelo \(AIReader.defaultModelTitle) · abrir laudo ao lado para conferir · mais em Configurações")
                }
                .padding(.top, 6)
            } label: {
                HStack(spacing: 6) {
                    MutedText("Leitura por IA · avançado")
                    HelpButton(topic: .aiReading)
                }
            }
            .tint(Theme.muted)
            .sheet(isPresented: $showKey) {
                APIKeyView(isChanging: reader.hasKey,
                           onSave: { _ in reader.refreshKey(); showKey = false },
                           onSkip: { showKey = false })
                    .keySheetFrame()
            }
        }
    }

    /// Mensagem de estado da leitura (info/ok/erro), com as cores da web.
    struct StatusView: View {
        let status: AIReaderState.Status

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(status.text).fontWeight(status.kind == .ok ? .semibold : .regular)
                ForEach(status.details, id: \.self) { Text($0) }
            }
            .font(.system(size: 12.5))
            .foregroundStyle(ink)
            .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(border))
        }

        private var ink: Color {
            switch status.kind { case .info: return Color(hex: 0x1e40af); case .ok: return Theme.okInk; case .error: return Theme.errInk }
        }
        private var bg: Color {
            switch status.kind { case .info: return Color(hex: 0xeff6ff); case .ok: return Theme.okBg; case .error: return Theme.errBg }
        }
        private var border: Color {
            switch status.kind { case .info: return Color(hex: 0xbfdbfe); case .ok: return Theme.okBorder; case .error: return Theme.errBorder }
        }
    }
}

private extension View {
    /// A sheet da chave precisa de tamanho mínimo só no Mac; no iPhone ocupa a tela.
    func keySheetFrame() -> some View {
        #if os(macOS)
        return frame(minWidth: 480, minHeight: 520)
        #else
        return self
        #endif
    }
}

#if os(iOS)
import VisionKit

/// Scanner de documentos do sistema (VisionKit): recorta e corrige a perspectiva de cada página.
struct DocumentScanner: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: ([UIImage]) -> Void
        init(onScan: @escaping ([UIImage]) -> Void) { self.onScan = onScan }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onScan((0..<scan.pageCount).map { scan.imageOfPage(at: $0) })
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { onScan([]) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { onScan([]) }
    }
}
#endif

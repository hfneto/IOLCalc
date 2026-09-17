import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// O laudo lido (fotos, imagens ou PDF) montado num único documento PDF para conferência: zoom,
/// rolagem e páginas pelo PDFKit. Fica ao lado da calculadora no Mac/iPad (`inspector`) e numa
/// folha no iPhone.
struct LaudoInspector: View {
    let files: [PickedFile]
    var onOpenFile: (([PickedFile]) -> Void)? = nil
    var onClose: () -> Void

    @State private var showFiles = false
    @State private var document: PDFDocument?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let document, document.pageCount > 0 {
                PDFKitView(document: document)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.viewfinder").font(.system(size: 34)).foregroundStyle(Theme.muted)
                    Text(files.isEmpty ? "Nenhum laudo aberto." : "Não foi possível mostrar este arquivo.")
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                    Text("Use \"Ler laudo com IA\" ou abra um arquivo aqui só para conferir.")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    PillButton(title: "Abrir arquivo…", systemImage: "folder") { showFiles = true }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bg)
            }
        }
        .task(id: files.map(\.name).joined()) { document = Self.makeDocument(files) }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            let picked = urls.compactMap(AIReadControls.load)
            if !picked.isEmpty { onOpenFile?(picked) }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass").foregroundStyle(Theme.brand)
            Text("Laudo").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
            if let document, document.pageCount > 0 {
                Chip(text: document.pageCount == 1 ? "1 página" : "\(document.pageCount) páginas")
            }
            Spacer()
            if onOpenFile != nil {
                Button { showFiles = true } label: { Image(systemName: "folder") }
                    .buttonStyle(.plain).foregroundStyle(Theme.brand).help("Abrir outro arquivo")
            }
            Button(action: onClose) { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted) }
                .buttonStyle(.plain).help("Fechar")
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Theme.card)
    }

    /// PDFs entram como estão; imagens viram uma página cada (orientação EXIF respeitada).
    static func makeDocument(_ files: [PickedFile]) -> PDFDocument? {
        let doc = PDFDocument()
        for file in files {
            let isPDF = file.type?.conforms(to: .pdf) == true || file.name.lowercased().hasSuffix(".pdf") || file.data.starts(with: [0x25, 0x50, 0x44, 0x46])
            if isPDF, let pdf = PDFDocument(data: file.data) {
                for i in 0..<pdf.pageCount { if let p = pdf.page(at: i) { doc.insert(p, at: doc.pageCount) } }
            } else if let image = PlatformImage(data: file.data), let page = PDFPage(image: image) {
                doc.insert(page, at: doc.pageCount)
            }
        }
        return doc.pageCount > 0 ? doc : nil
    }
}

#if os(iOS)
typealias PlatformImage = UIImage
#else
typealias PlatformImage = NSImage
#endif

/// `PDFView` do PDFKit: zoom por pinça/scroll, páginas contínuas, ajuste automático à largura.
struct PDFKitView: PlatformViewRepresentable {
    let document: PDFDocument

    private func configure(_ view: PDFView) {
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.minScaleFactor = 0.25
        view.maxScaleFactor = 8
        #if os(iOS)
        view.backgroundColor = UIColor(Theme.bg)
        #else
        view.backgroundColor = NSColor(Theme.bg)
        #endif
    }

    #if os(iOS)
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        configure(v)
        v.document = document
        return v
    }
    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document; view.autoScales = true }
    }
    #else
    func makeNSView(context: Context) -> PDFView {
        let v = PDFView()
        configure(v)
        v.document = document
        return v
    }
    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document; view.autoScales = true }
    }
    #endif
}

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit
import PDFKit

struct MarkdownFile: FileDocument {
    static var readableContentTypes: [UTType] { [UTType(filenameExtension: "md") ?? .plainText] }
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(data: data, encoding: .utf8) ?? ""
        } else {
            text = ""
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }
}

struct NoteDetailView: View {
    @Bindable var note: Note
    @Binding var selectedNote: Note?
    @Binding var showGraph: Bool
    
    @Query private var allNotes: [Note]
    
    @State private var images: [String: NSImage] = [:]
    @State private var isExporting = false
    @State private var documentToExport: MarkdownFile?
    
    @AppStorage("backlinks_height") private var backlinksHeight: Double = 150
    @State private var isHoveringDivider = false
    
    private var wordCount: Int {
        note.content.split { $0.isWhitespace }.count
    }
    
    private var charCount: Int {
        note.content.count
    }
    
    private var readTime: Int {
        let wordsPerMinute = 200
        return max(1, wordCount / wordsPerMinute)
    }
    
    private var backlinks: [Note] {
        allNotes.filter { $0.content.contains("[[\(note.title)]]") && $0.id != note.id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { _ in
                VStack(spacing: 0) {
                    Group {
                        if note.fileData != nil {
                            FilePreviewView(note: note)
                        } else {
                            RichMarkdownEditor(note: note, images: $images, selectedNote: $selectedNote)
                                .padding(.top, 5)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if !backlinks.isEmpty {
                        resizableDivider
                        
                        backlinksSection
                            .frame(height: CGFloat(backlinksHeight))
                            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                    }
                }
            }
            
            statisticsBar
        }
        .navigationTitle(note.title)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    withAnimation(.smooth(duration: 0.35)) {
                        showGraph.toggle()
                    }
                } label: {
                    Image(systemName: showGraph ? "sidebar.right" : "sidebar.right")
                        .symbolVariant(showGraph ? .fill : .none)
                }
                .help(showGraph ? "Hide Graph" : "Show Graph")
                
                Button {
                    note.isPinned.toggle()
                } label: {
                    Image(systemName: note.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(note.isPinned ? .orange : .primary)
                }
                .help(note.isPinned ? "Unpin Note" : "Pin Note")

                Menu {
                    Button(action: shareViaService) {
                        Label("Share...", systemImage: "square.and.arrow.up")
                    }
                    
                    if note.fileData == nil {
                        Button(action: {
                            documentToExport = MarkdownFile(text: note.content)
                            isExporting = true
                        }) {
                            Label("Export as .md...", systemImage: "arrow.down.doc")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Share or Export")
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: documentToExport,
            contentType: UTType(filenameExtension: "md") ?? .plainText,
            defaultFilename: sanitizeFilename(note.title)
        ) { _ in }
    }
        
    private var resizableDivider: some View {
        ZStack {
            Rectangle()
                .fill(Color.primary.opacity(isHoveringDivider ? 0.2 : 0.05))
                .frame(height: 4)
            
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 1)
        }
        .onHover { hovering in
            isHoveringDivider = hovering
            if hovering {
                NSCursor.resizeUpDown.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let newHeight = CGFloat(backlinksHeight) - value.translation.height
                    backlinksHeight = Double(max(100, min(newHeight, 500)))
                }
        )
    }

    private var backlinksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Linked Mentions")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(backlinks) { link in
                        Button {
                            selectedNote = link
                        } label: {
                            HStack {
                                Image(systemName: "link")
                                    .font(.caption)
                                Text(link.title)
                                    .font(.body)
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
        }
    }
    
    private var statisticsBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 15) {
                HStack(spacing: 4) {
                    Text("\(wordCount)").fontWeight(.bold)
                    Text("words")
                }
                HStack(spacing: 4) {
                    Text("\(charCount)").fontWeight(.bold)
                    Text("characters")
                }
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("\(readTime) min read")
                }
                
                Spacer()
                
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 15)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
        }
    }
        
    private func shareViaService() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(sanitizeFilename(note.title))
        do {
            if let data = note.fileData, let ext = note.fileExtension {
                let fileURL = tempURL.appendingPathExtension(ext)
                try data.write(to: fileURL)
                showPicker(items: [fileURL])
            } else {
                let fileURL = tempURL.appendingPathExtension("md")
                try note.content.write(to: fileURL, atomically: true, encoding: .utf8)
                showPicker(items: [fileURL])
            }
        } catch { print(error) }
    }
    
    private func showPicker(items: [Any]) {
        let picker = NSSharingServicePicker(items: items)
        if let window = NSApp.keyWindow, let view = window.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }

    private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return filename.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}

struct FilePreviewView: View {
    @Bindable var note: Note
    
    var body: some View {
        VStack {
            let data = note.fileData ?? Data()
            let fileExtension = note.fileExtension ?? ""
            
            if ["png", "jpg", "jpeg", "gif"].contains(fileExtension.lowercased()) {
                if let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
            } else if fileExtension.lowercased() == "pdf" {
                PDFKitRepresentedView(note: note)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    Text("\(note.title).\(fileExtension)").font(.title3)
                    Button("Open Externally") {
                        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("\(note.title).\(fileExtension)")
                        try? data.write(to: temp)
                        NSWorkspace.shared.open(temp)
                    }.buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct PDFKitRepresentedView: NSViewRepresentable {
    @Bindable var note: Note
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        
        if let data = note.fileData {
            pdfView.document = PDFDocument(data: data)
        }
        
        if let document = pdfView.document,
           let page = document.page(at: note.lastPDFPage) {
            pdfView.go(to: page)
        }
        
        context.coordinator.setupNotification(for: pdfView)
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(note: note)
    }
    
    class Coordinator: NSObject {
        var note: Note
        private var isInitialPageSet = false
        
        init(note: Note) {
            self.note = note
        }
        
        func setupNotification(for pdfView: PDFView) {
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handlePageChange(notification:)),
                name: .PDFViewPageChanged,
                object: pdfView
            )
        }
        
        @objc func handlePageChange(notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            
            let pageIndex = document.index(for: currentPage)
            
            if note.lastPDFPage != pageIndex {
                DispatchQueue.main.async {
                    self.note.lastPDFPage = pageIndex
                }
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

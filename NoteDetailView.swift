import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit
import PDFKit

struct NoteDetailView: View {
    @Bindable var note: Note
    @Binding var selectedNote: Note?
    @Binding var showGraph: Bool
    
    @Query private var allNotes: [Note]
    
    @State private var images: [String: NSImage] = [:]
    @State private var isExporting = false
    @State private var documentToExport: MarkdownFile?
    
    // Состояние для регулировки высоты обратных ссылок
    @AppStorage("backlinks_height") private var backlinksHeight: Double = 150
    @State private var isHoveringDivider = false
    
    // Статистика
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
    
    // Обратные ссылки (Backlinks)
    private var backlinks: [Note] {
        allNotes.filter { $0.content.contains("[[\(note.title)]]") && $0.id != note.id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ОСНОВНОЙ КОНТЕНТ (Редактор или Файл)
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Group {
                        if let data = note.fileData, let ext = note.fileExtension {
                            FilePreviewView(data: data, fileExtension: ext, title: note.title)
                        } else {
                            RichMarkdownEditor(note: note, images: $images, selectedNote: $selectedNote)
                                .padding(.top, 5)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // БЛОК ОБРАТНЫХ ССЫЛОК С РЕГУЛИРОВКОЙ
                    if !backlinks.isEmpty {
                        resizableDivider
                        
                        backlinksSection
                            .frame(height: CGFloat(backlinksHeight))
                            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                    }
                }
            }
            
            // НИЖНЯЯ ПАНЕЛЬ СТАТИСТИКИ
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
                
                Button {
                    note.isPinned.toggle()
                } label: {
                    Image(systemName: note.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(note.isPinned ? .orange : .primary)
                }

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
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: documentToExport,
            contentType: UTType(filenameExtension: "md") ?? .plainText,
            defaultFilename: sanitizeFilename(note.title)
        ) { _ in }
    }
    
    // РАЗДЕЛИТЕЛЬ ДЛЯ ТЯГИ (RESIZER)
    private var resizableDivider: some View {
        ZStack {
            Rectangle()
                .fill(Color.primary.opacity(isHoveringDivider ? 0.2 : 0.05))
                .frame(height: 4)
            
            // Тонкая линия-декоратор
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
                    // Инвертируем движение: тянем вверх — высота увеличивается
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
                    Text("слов")
                }
                HStack(spacing: 4) {
                    Text("\(charCount)").fontWeight(.bold)
                    Text("знаков")
                }
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("\(readTime) мин")
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

    // Вспомогательные функции (Export, Share, Sanitize) остаются без изменений
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

// Вспомогательные структуры (MarkdownFile, FilePreviewView, PDFKitRepresentedView)
struct MarkdownFile: FileDocument {
    static var readableContentTypes: [UTType] { [UTType(filenameExtension: "md") ?? .plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(data: data, encoding: .utf8) ?? ""
        } else { text = "" }
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }
}

struct FilePreviewView: View {
    let data: Data
    let fileExtension: String
    let title: String
    var body: some View {
        VStack {
            if ["png", "jpg", "jpeg", "gif"].contains(fileExtension.lowercased()) {
                if let img = NSImage(data: data) {
                    Image(nsImage: img).resizable().scaledToFit().padding()
                }
            } else if fileExtension.lowercased() == "pdf" {
                PDFKitRepresentedView(data: data)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.circle.fill").font(.system(size: 64)).foregroundStyle(.secondary)
                    Text("\(title).\(fileExtension)").font(.title3)
                    Button("Open Externally") {
                        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("\(title).\(fileExtension)")
                        try? data.write(to: temp)
                        NSWorkspace.shared.open(temp)
                    }.buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

struct PDFKitRepresentedView: NSViewRepresentable {
    let data: Data
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: data)
        pdfView.autoScales = true
        return pdfView
    }
    func updateNSView(_ nsView: PDFView, context: Context) {}
}

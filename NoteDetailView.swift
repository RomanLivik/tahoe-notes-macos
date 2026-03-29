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
    
    @State private var images: [String: NSImage] = [:]
    @State private var isExporting = false
    @State private var documentToExport: MarkdownFile?
    
    var body: some View {
        Group {
            if let data = note.fileData, let ext = note.fileExtension {
                FilePreviewView(data: data, fileExtension: ext, title: note.title)
            } else {
                RichMarkdownEditor(note: note, images: $images, selectedNote: $selectedNote)
            }
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
    let data: Data
    let fileExtension: String
    let title: String
    
    var body: some View {
        VStack {
            if ["png", "jpg", "jpeg", "gif"].contains(fileExtension.lowercased()) {
                if let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
            } else if fileExtension.lowercased() == "pdf" {
                PDFKitRepresentedView(data: data)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    Text("\(title).\(fileExtension)").font(.title3)
                    Button("Open in External App") {
                        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("\(title).\(fileExtension)")
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
    let data: Data
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: data)
        pdfView.autoScales = true
        return pdfView
    }
    func updateNSView(_ nsView: PDFView, context: Context) {}
}

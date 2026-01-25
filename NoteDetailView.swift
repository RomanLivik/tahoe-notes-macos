import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

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
        RichMarkdownEditor(note: note, images: $images, selectedNote: $selectedNote)
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
                        
                        Button(action: {
                            documentToExport = MarkdownFile(text: note.content)
                            isExporting = true
                        }) {
                            Label("Export as .md...", systemImage: "arrow.down.doc")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Share or Export Note")
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: documentToExport,
                contentType: UTType(filenameExtension: "md") ?? .plainText,
                defaultFilename: sanitizeFilename(note.title)
            ) { result in
                switch result {
                case .success(let url):
                    print("Note saved to: \(url.path)")
                case .failure(let error):
                    print("Export failed: \(error.localizedDescription)")
                }
            }
            .onDrop(of: [.fileURL, .image], delegate: SimpleDropDelegate(note: note))
    }
    
    private func shareViaService() {
        let safeTitle = sanitizeFilename(note.title)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(safeTitle)
            .appendingPathExtension("md")
        
        do {
            try note.content.write(to: tempURL, atomically: true, encoding: .utf8)
            let picker = NSSharingServicePicker(items: [tempURL])
            
            if let window = NSApp.keyWindow, let contentView = window.contentView {
                let rect = NSRect(x: contentView.bounds.width - 40, y: contentView.bounds.height - 40, width: 0, height: 0)
                picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
            }
        } catch {
            print("Error preparing share file: \(error)")
        }
    }
    
    private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return filename.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}

struct SimpleDropDelegate: DropDelegate {
    let note: Note
    
    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.fileURL, .image])
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url { saveAndAppend(source: url) }
                }
            }
            else if provider.canLoadObject(ofClass: NSImage.self) {
                provider.loadObject(ofClass: NSImage.self) { image, _ in
                    if let image = image as? NSImage { saveAndAppend(source: image) }
                }
            }
        }
        return true
    }
    
    private func saveAndAppend(source: Any) {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let assetsDir = docsDir.appendingPathComponent("TahoeNotes/assets")
        
        try? FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        
        let imageName = "img_\(UUID().uuidString.prefix(6)).png"
        let fileURL = assetsDir.appendingPathComponent(imageName)
        let relativePath = "assets/\(imageName)"
        
        if let url = source as? URL {
            try? FileManager.default.copyItem(at: url, to: fileURL)
        } else if let image = source as? NSImage {
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
               let data = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) {
                try? data.write(to: fileURL)
            }
        }
        
        DispatchQueue.main.async {
            note.content += "\n\n![image](\(relativePath))\n"
            try? note.modelContext?.save()
        }
    }
}

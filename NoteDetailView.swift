import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct NoteDetailView: View {
    let note: Note
    @Binding var selectedNote: Note?
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        RichMarkdownEditor(note: note)
            .navigationTitle(note.title)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Menu("Share") {
                        Button("Current") { shareNote() }
                    }
                }
            }
            .onDrop(of: [.fileURL, .image], delegate: NoteDropDelegate(note: note))
    }
    
    private func shareNote() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).md")
        try? note.content.write(to: tempURL, atomically: true, encoding: .utf8)
        
        let activityVC = NSSharingServicePicker(items: [tempURL])
        if let view = NSApp.keyWindow?.contentView {
            activityVC.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }
}

struct NoteDropDelegate: DropDelegate {
    let note: Note
    
    func performDrop(info: DropInfo) -> Bool {
        for provider in info.itemProviders(for: [.fileURL, .image]) {
            provider.loadObject(ofClass: NSImage.self) { image, _ in
                if let image = image as? NSImage {
                    let imageId = UUID().uuidString.prefix(8)
                    DispatchQueue.main.async {
                        note.content += "\n![Image \(imageId)]()\n"
                    }
                }
            }
        }
        return true
    }
}


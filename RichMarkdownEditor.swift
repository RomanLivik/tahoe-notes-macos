import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct EscapeHandler: NSViewRepresentable {
    let onEscape: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            view?.window?.makeFirstResponder(view)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension NSView {
    open override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            NotificationCenter.default.post(name: NSNotification.Name("escapePressed"), object: nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

struct RichMarkdownEditor: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext
    @State private var editMode = false  // Preview по умолчанию
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(editMode ? "Preview" : "Edit") {
                    editMode.toggle()
                }
                Spacer()
                Button("Save") {
                    try? modelContext.save()
                    editMode = false
                }
            }
            .padding()
            .background(.regularMaterial)
            
            Group {
                if editMode {
                    MarkdownInput(note: note)
                } else {
                    MarkdownPreview(markdown: note.content)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .onDrop(of: [.fileURL, .image], delegate: NoteDropDelegate(note: note))
        .background(
            EscapeHandler {
                try? modelContext.save()
                editMode = false
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("escapePressed"))) { _ in
            try? modelContext.save()
            editMode = false
        }
    }
}


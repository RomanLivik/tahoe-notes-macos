import SwiftUI
import SwiftData

struct RichMarkdownEditor: View {
    @Bindable var note: Note
    let images: Binding<[String: NSImage]>
    @Binding var selectedNote: Note?
    @Environment(\.modelContext) private var modelContext
    @State private var editMode = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(editMode ? "Preview" : "Edit") {
                    editMode.toggle()
                    if !editMode { try? modelContext.save() }
                }
                Spacer()
                if editMode {
                    Button("Save") {
                        try? modelContext.save()
                        editMode = false
                    }.buttonStyle(.borderedProminent)
                }
            }.padding(10).background(.regularMaterial)
            Divider()
            Group {
                if editMode { MarkdownInput(note: note) }
                else { MarkdownPreview(markdown: note.content, images: images.wrappedValue, selectedNote: $selectedNote) }
            }.frame(maxHeight: .infinity)
        }
        .background(EscapeHandler { try? modelContext.save(); editMode = false })
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("escapePressed"))) { _ in
            try? modelContext.save()
            editMode = false
        }
    }
}

struct EscapeHandler: NSViewRepresentable {
    let onEscape: () -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension NSView {
    open override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { NotificationCenter.default.post(name: NSNotification.Name("escapePressed"), object: nil) }
        else { super.keyDown(with: event) }
    }
}

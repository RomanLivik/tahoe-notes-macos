import SwiftUI
import SwiftData

struct MarkdownInput: View {
    @Bindable var note: Note
    
    var body: some View {
        TextEditor(text: $note.content)
            .font(.system(.body, design: .monospaced))
            .frame(maxHeight: .infinity)
            .padding()
            .scrollContentBackground(.hidden)
            .background(Color(NSColor.controlBackgroundColor))
            .onChange(of: note.content) {
                try? note.modelContext?.save()
            }
    }
}

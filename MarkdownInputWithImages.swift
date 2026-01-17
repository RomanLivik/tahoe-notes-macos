import SwiftUI
import SwiftData

struct MarkdownInputWithImages: View {
    @Bindable var note: Note
    @Binding var images: [String: NSImage]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                formatButton(title: "**B**", marker: "**")
                formatButton(title: "*I*", marker: "*")
                formatButton(title: "`Code`", marker: "`")
                formatButton(title: "# H1", marker: "# ")
                formatButton(title: "Image", marker: "![")
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            
            TextEditor(text: $note.content)
                .font(.system(.body, design: .monospaced))
                .frame(maxHeight: .infinity)
                .padding()
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .onChange(of: note.content) {
            try? note.modelContext?.save()
        }
    }
    
    @ViewBuilder
    private func formatButton(title: String, marker: String) -> some View {
        Button(title) {
            wrapText(marker: marker)
        }
    }
    
    private func wrapText(marker: String) {
        let content = note.content
        
        if content.isEmpty {
            note.content = "\(marker)text\(marker)\n"
            return
        }
        
        let newText = content + "\n\(marker)text\(marker)"
        note.content = newText
    }
    
    private func insertImagePlaceholder() {
        let imageId = UUID().uuidString.prefix(8)
        note.content += "\n![image-\(imageId)]()  ← Drag image here\n"
    }
}


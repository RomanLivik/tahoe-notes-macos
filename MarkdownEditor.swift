import SwiftUI
import SwiftData

struct MarkdownEditor: View {
    @Bindable var note: Note 
    @Environment(\.modelContext) private var modelContext
    @State private var editMode = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(editMode ? "Preview" : "Edit") {
                    editMode.toggle()
                }
                Spacer()
                Button("Save") {
                    try? modelContext.save()
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
    }
}


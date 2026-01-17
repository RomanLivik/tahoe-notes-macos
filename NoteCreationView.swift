import SwiftUI
import SwiftData

struct NoteCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    let parentNote: Note?
    
    init(parentNote: Note? = nil) {
        self.parentNote = parentNote
    }
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Note name", text: $title)
            }
            .navigationTitle("New note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let newNote = Note(title: title.isEmpty ? "New note" : title,
                                         parentNote: parentNote)
                        modelContext.insert(newNote)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}


import SwiftUI
import SwiftData

struct NoteCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Folder.name) private var folders: [Folder]
    
    let parentNote: Note?
    
    @State private var title = ""
    @State private var selectedFolderID: PersistentIdentifier? 
    
    init(parentNote: Note? = nil) {
        self.parentNote = parentNote
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Note Details")) {
                    TextField("Note name", text: $title)
                        .font(.body)
                    
                    if let parent = parentNote {
                        HStack {
                            Text("Sub-note of:")
                                .foregroundStyle(.secondary)
                            Text(parent.title)
                                .fontWeight(.bold)
                        }
                        .font(.caption)
                    } else {
                        Picker("Folder", selection: $selectedFolderID) {
                            Text("None (Root)").tag(nil as PersistentIdentifier?)
                            ForEach(folders) { folder in
                                Text(folder.name).tag(folder.id as PersistentIdentifier?)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(parentNote == nil ? "New Note" : "New Sub-note")
            .frame(width: 400, height: 280)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createNewNote()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func createNewNote() {
        let newNote = Note(title: title.isEmpty ? "New note" : title)
        
        if let parent = parentNote {
            newNote.parentNote = parent
            newNote.folder = parent.folder 
        } else if let folderID = selectedFolderID,
                  let folder = folders.first(where: { $0.id == folderID }) {
            newNote.folder = folder 
        }
        
        modelContext.insert(newNote)
        try? modelContext.save()
        dismiss()
    }
}

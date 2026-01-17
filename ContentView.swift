import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var rootNotes: [Note]
    @State private var selectedNote: Note?
    
    var body: some View {
        NavigationSplitView {
            List(rootNotes, id: \.self, selection: $selectedNote) { note in
                NavigationLink(value: note) {
                    Label(note.title, systemImage: "doc.text")
                }
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        deleteNote(note)
                    }
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createNewRootNote) {
                        Image(systemName: "plus")
                    }
                    .help("Create note")
                    .keyboardShortcut("n")
                }
            }
            .listStyle(SidebarListStyle())
        } detail: {
            Group {
                if let note = selectedNote {
                    NoteDetailView(note: note, selectedNote: $selectedNote)
                } else {
                    WelcomeView()
                }
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
    
    private func deleteNote(_ note: Note) {
        modelContext.delete(note)
        try? modelContext.save()
        if selectedNote == note {
            selectedNote = rootNotes.first
        }
    }
    
    private func createNewRootNote() {
        let newNote = Note()
        newNote.title = "New note"
        newNote.content = "# New note"
        newNote.parentNote = nil
        
        modelContext.insert(newNote)
        try? modelContext.save()
        selectedNote = newNote
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Note.self, inMemory: true)
}


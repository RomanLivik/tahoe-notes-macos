import SwiftUI
import SwiftData

    struct SubnotesTab: View {
        let note: Note
        let subnotes: [Note]
        @Environment(\.modelContext) private var modelContext
        @State private var showingNewSubnote = false
        
        var body: some View {
            List(subnotes, id: \.self) { subnote in
                NavigationLink(value: subnote) {
                    VStack(alignment: .leading) {
                        Text(subnote.title).font(.headline)
                        Text(subnote.content.prefix(100)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("+ New") { showingNewSubnote = true }
                }
            }
            .sheet(isPresented: $showingNewSubnote) {
                NoteCreationView(parentNote: note)
            }
        }
    }


import SwiftUI
import SwiftData

struct SidebarView: View {
    @Query private var notes: [Note]
    @Binding var selectedNote: Note?
    
    var body: some View {
        List(notes.filter { $0.parentNote == nil },
             id: \.self,
             selection: $selectedNote) { note in
            Label(note.title, systemImage: "doc.text")
        }
        .navigationTitle("Notes")
        .listStyle(SidebarListStyle())
    }
}


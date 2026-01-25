import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedNote: Note?
    
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showGraph = true
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedNote: $selectedNote)
                .navigationSplitViewColumnWidth(min: 250, ideal: 300)
            
        } content: {
            Group {
                if let note = selectedNote {
                    NoteDetailView(note: note, selectedNote: $selectedNote, showGraph: $showGraph)
                        .id(note.id)
                } else {
                    WelcomeView()
                }
            }
            .navigationSplitViewColumnWidth(min: 500, ideal: 700)
            
        } detail: {
            if showGraph {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Graph View")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 20)
                        .padding(.top, 16)
                    
                    GraphView(selectedNote: $selectedNote)
                }
                .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
                .navigationSplitViewColumnWidth(min: 250, ideal: 350, max: 500)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
            } else {
                Color.clear
                    .navigationSplitViewColumnWidth(0)
            }
        }
        .frame(minWidth: 1100, minHeight: 750)
    }
}

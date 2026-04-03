import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.title) private var allNotes: [Note]
    
    @State private var selectedNote: Note?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showGraph = true
    
    @State private var isCommandPalettePresented = false
    @State private var cmdSearchText = ""
    
    var body: some View {
        ZStack {
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
                } else {
                    Color.clear.navigationSplitViewColumnWidth(0)
                }
            }
            
            if isCommandPalettePresented {
                commandPaletteView
            }
        }
        .frame(minWidth: 1100, minHeight: 750)
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let commandKey = event.modifierFlags.contains(.command)
                if commandKey && event.charactersIgnoringModifiers == "k" {
                    withAnimation(.spring(duration: 0.3)) {
                        isCommandPalettePresented.toggle()
                        cmdSearchText = ""
                    }
                    return nil
                }
                
                if event.keyCode == 53 && isCommandPalettePresented { // Escape key
                    isCommandPalettePresented = false
                    return nil
                }
                
                return event
            }
        }
    }
    
    private var commandPaletteView: some View {
        VStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    
                    TextField("Quick Open Note...", text: $cmdSearchText)
                        .textFieldStyle(.plain)
                        .font(.title2)
                }
                .padding(20)
                
                Divider()
                
                let results = allNotes.filter {
                    cmdSearchText.isEmpty || $0.title.localizedCaseInsensitiveContains(cmdSearchText)
                }
                
                if !results.isEmpty {
                    List(results.prefix(10), id: \.id) { note in
                        Button {
                            selectedNote = note
                            isCommandPalettePresented = false
                        } label: {
                            HStack {
                                Image(systemName: note.fileData != nil ? "doc.append" : "doc.text")
                                    .foregroundStyle(note.isPinned ? .orange : .secondary)
                                Text(note.title)
                                    .font(.body)
                                Spacer()
                                if note.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                                Text("Open")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                    .frame(height: min(CGFloat(results.count * 40), 400))
                } else {
                    Text("No notes found")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .background(.ultraThinMaterial)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .frame(width: 600)
            .padding(.top, 120)
            .shadow(color: .black.opacity(0.3), radius: 30)
            
            Spacer()
        }
        .background(Color.black.opacity(0.15))
        .onTapGesture { isCommandPalettePresented = false }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

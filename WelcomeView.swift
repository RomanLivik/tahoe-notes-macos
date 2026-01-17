import SwiftUI
import SwiftData

struct WelcomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewNote = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            
            Text("Welcome to Tahoe Notes")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Create first note to get started")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Button("+ New note") {
                showingNewNote = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingNewNote) {
            NoteCreationView()
        }
    }
}


import SwiftUI
import SwiftData

@main
struct TahoeNotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Note.self)
    }
}


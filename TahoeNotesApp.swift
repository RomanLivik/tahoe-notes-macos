import SwiftUI
import SwiftData

@main
struct TahoeNotesApp: App {
    @AppStorage("app_theme") private var appTheme = "system"
    @AppStorage("app_language") private var appLanguage = "en"
    @AppStorage("app_accent_color") private var appAccentColor = "azure"
    
    var body: some Scene {
        WindowGroup {
            let currentAccent = AppAccentColor(rawValue: appAccentColor)?.color ?? .cyan
            
            ContentView()
                .environment(\.locale, .init(identifier: appLanguage))
                .preferredColorScheme(getSelectedScheme())
                .tint(currentAccent)
                .accentColor(currentAccent)
        }
        .modelContainer(for: [Note.self, Folder.self])
        
        Settings {
            SettingsView()
                .environment(\.locale, .init(identifier: appLanguage))
        }
    }
    
    private func getSelectedScheme() -> ColorScheme? {
        if appTheme == "light" { return .light }
        if appTheme == "dark" { return .dark }
        return nil
    }
}

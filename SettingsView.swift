import SwiftUI

enum AppAccentColor: String, CaseIterable, Identifiable {
    case red, green, purple, azure
    
    var id: String { self.rawValue }
    
    var color: Color {
        switch self {
        case .red: return .red
        case .green: return .green
        case .purple: return .purple
        case .azure: return .cyan
        }
    }
    
    var title: LocalizedStringKey {
        switch self {
        case .red: return "Red"
        case .green: return "Green"
        case .purple: return "Purple"
        case .azure: return "Azure"
        }
    }
}

struct SettingsView: View {
    @AppStorage("app_theme") private var appTheme = "system"
    @AppStorage("app_language") private var appLanguage = "en"
    @AppStorage("app_accent_color") private var appAccentColor = "azure"
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.return)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $appTheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }.pickerStyle(.radioGroup)
                    
                    Divider()
                    
                    Picker("Accent Color", selection: $appAccentColor) {
                        ForEach(AppAccentColor.allCases) { accent in
                            HStack {
                                Circle().fill(accent.color).frame(width: 8, height: 8)
                                Text(accent.title)
                            }.tag(accent.rawValue)
                        }
                    }
                }
                
                Section(header: Text("Language")) {
                    Picker("Interface Language", selection: $appLanguage) {
                        Text("English").tag("en")
                        Text("Russian").tag("ru")
                        Text("German").tag("de")
                        Text("Chinese").tag("zh-Hans")
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 400)
    }
}

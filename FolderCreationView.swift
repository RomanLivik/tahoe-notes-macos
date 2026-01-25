import SwiftUI
import SwiftData

struct FolderCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("New Folder").font(.title2).fontWeight(.medium)
                TextField("Folder name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .padding(16).frame(maxWidth: 350)
            }
            .padding(20).frame(minWidth: 400, minHeight: 180)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let newFolder = Folder(name: name.isEmpty ? "New Folder" : name)
                        modelContext.insert(newFolder)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

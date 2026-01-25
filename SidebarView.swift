import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum SidebarMode: String, CaseIterable, Identifiable {
    case notes, tasks
    var id: String { self.rawValue }
    var icon: String { self == .notes ? "doc.text" : "checklist" }
    var title: LocalizedStringKey { self == .notes ? "Notes" : "Tasks" }
}

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Folder.name) private var folders: [Folder]
    @Query(filter: #Predicate<Note> { $0.folder == nil && $0.parentNote == nil })
    private var rootNotes: [Note]
    @Query private var allNotes: [Note]
    
    @Binding var selectedNote: Note?
    @AppStorage("app_accent_color") private var appAccentColor = "azure"
    
    @State private var sidebarMode: SidebarMode = .notes
    @State private var searchText = ""
    
    @State private var showingSettings = false
    @State private var showingNewFolderSheet = false
    @State private var showingNewNoteSheet = false
    @State private var noteToCreateSubnoteFor: Note?

    private var currentAccent: Color {
        AppAccentColor(rawValue: appAccentColor)?.color ?? .cyan
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $sidebarMode) {
                ForEach(SidebarMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ZStack {
                if sidebarMode == .notes {
                    notesTreeView
                } else {
                    GlobalTaskListView(allNotes: allNotes, currentAccent: currentAccent, selectedNote: $selectedNote, searchText: searchText)
                }
            }
            
            Divider()
            
            HStack {
                bottomAction(icon: "note.text.badge.plus", help: "New Note") {
                    noteToCreateSubnoteFor = nil
                    showingNewNoteSheet = true
                }
                Spacer()
                bottomAction(icon: "folder.badge.plus", help: "New Folder") {
                    showingNewFolderSheet = true
                }
                Spacer()
                bottomAction(icon: "square.and.arrow.down", help: "Import .md") {
                    importMarkdownFiles()
                }
                Spacer()
                bottomAction(icon: "gearshape", help: "Settings") {
                    showingSettings = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: Text("Search..."))
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingNewFolderSheet) { FolderCreationView() }
        .sheet(isPresented: $showingNewNoteSheet) {
            NoteCreationView(parentNote: noteToCreateSubnoteFor)
        }
    }
    
    @ViewBuilder
    private func bottomAction(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(currentAccent)
        .help(help)
    }

    private var notesTreeView: some View {
        List(selection: $selectedNote) {
            if !searchText.isEmpty {
                Section("Search Results") {
                    let filtered = allNotes.filter {
                        $0.title.localizedCaseInsensitiveContains(searchText) ||
                        $0.content.localizedCaseInsensitiveContains(searchText)
                    }
                    ForEach(filtered) { note in
                        NavigationLink(value: note) {
                            VStack(alignment: .leading) {
                                Label(note.title, systemImage: "doc.text").foregroundStyle(currentAccent)
                                if note.content.localizedCaseInsensitiveContains(searchText) {
                                    Text(note.content).font(.caption2).lineLimit(1).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else {
                if !folders.isEmpty {
                    Section("Folders") {
                        ForEach(folders) { folder in
                            DisclosureGroup {
                                ForEach(folder.notes.filter { $0.parentNote == nil }) { note in
                                    RecursiveNoteView(note: note, currentAccent: currentAccent, selectedNote: $selectedNote, folders: folders, onAddSubnote: {
                                        self.noteToCreateSubnoteFor = note
                                        self.showingNewNoteSheet = true
                                    })
                                }
                            } label: {
                                Label(folder.name, systemImage: "folder.fill").foregroundStyle(currentAccent)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { modelContext.delete(folder) } label: { Label("Delete", systemImage: "trash") }
                            }
                            .onDrop(of: [.fileURL], isTargeted: nil) { handleFileDrop($0, into: folder) }
                        }
                    }
                }
                
                Section("Notes") {
                    ForEach(rootNotes) { note in
                        RecursiveNoteView(note: note, currentAccent: currentAccent, selectedNote: $selectedNote, folders: folders, onAddSubnote: {
                            self.noteToCreateSubnoteFor = note
                            self.showingNewNoteSheet = true
                        })
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onDrop(of: [.fileURL], isTargeted: nil) { handleFileDrop($0) }
    }

    private func importMarkdownFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        if panel.runModal() == .OK {
            for url in panel.urls { createNoteFromURL(url) }
        }
    }
    
    private func handleFileDrop(_ providers: [NSItemProvider], into folder: Folder? = nil) -> Bool {
        for provider in providers {
            provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, url.pathExtension.lowercased() == "md" {
                    DispatchQueue.main.async { createNoteFromURL(url, into: folder) }
                }
            }
        }
        return true
    }
    
    private func createNoteFromURL(_ url: URL, into folder: Folder? = nil) {
        if let content = try? String(contentsOf: url) {
            let newNote = Note(title: url.deletingPathExtension().lastPathComponent, content: content)
            newNote.folder = folder
            modelContext.insert(newNote)
            try? modelContext.save()
        }
    }
}

struct RecursiveNoteView: View {
    let note: Note
    let currentAccent: Color
    @Binding var selectedNote: Note?
    let folders: [Folder]
    let onAddSubnote: () -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if note.children.isEmpty {
                NavigationLink(value: note) {
                    Label(note.title, systemImage: "doc.text").foregroundStyle(currentAccent)
                }
                .contextMenu { noteMenu }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { deleteThisNote() } label: { Label("Delete", systemImage: "trash") }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button { onAddSubnote() } label: { Image(systemName: "plus") }.tint(currentAccent)
                }
            } else {
                DisclosureGroup {
                    ForEach(note.children.sorted(by: { $0.title < $1.title })) { child in
                        RecursiveNoteView(note: child, currentAccent: currentAccent, selectedNote: $selectedNote, folders: folders, onAddSubnote: onAddSubnote)
                    }
                } label: {
                    NavigationLink(value: note) {
                        Label(note.title, systemImage: "doc.text.fill").foregroundStyle(currentAccent)
                    }
                    .contextMenu { noteMenu }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { deleteThisNote() } label: { Label("Delete", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button { onAddSubnote() } label: { Image(systemName: "plus") }.tint(currentAccent)
                    }
                }
            }
        }
    }
    
    private func deleteThisNote() {
        if selectedNote == note { selectedNote = nil }
        modelContext.delete(note)
    }
    
    @ViewBuilder
    var noteMenu: some View {
        Button(action: onAddSubnote) { Label("Add Sub-note", systemImage: "arrow.turn.down.right") }
        Divider()
        Menu("Move to Folder...") {
            Button("None (Root)") { note.folder = nil; try? modelContext.save() }
            ForEach(folders) { folder in
                Button(folder.name) { note.folder = folder; try? modelContext.save() }
            }
        }
        Divider()
        Button("Delete", role: .destructive) { deleteThisNote() }
    }
}

struct GlobalTaskListView: View {
    let allNotes: [Note]
    let currentAccent: Color
    @Binding var selectedNote: Note?
    let searchText: String
    
    struct GlobalTask: Identifiable {
        let id = UUID()
        let note: Note
        let content: String
        let isDone: Bool
        let lineIndex: Int
    }
    
    private var filteredTasks: [GlobalTask] {
        var tasks: [GlobalTask] = []
        for note in allNotes {
            let lines = note.content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") {
                    let taskContent = String(trimmed.dropFirst(6))
                    let matchesSearch = searchText.isEmpty || taskContent.localizedCaseInsensitiveContains(searchText) || note.title.localizedCaseInsensitiveContains(searchText)
                    if matchesSearch {
                        tasks.append(GlobalTask(note: note, content: taskContent, isDone: trimmed.hasPrefix("- [x] "), lineIndex: index))
                    }
                }
            }
        }
        return tasks
    }
    
    var body: some View {
        List {
            if filteredTasks.isEmpty {
                ContentUnavailableView(searchText.isEmpty ? "No Tasks" : "No Results", systemImage: "checklist", description: Text("Tasks added via - [ ] will appear here."))
            } else {
                let grouped = Dictionary(grouping: filteredTasks, by: { $0.note })
                ForEach(grouped.keys.sorted(by: { $0.title < $1.title }), id: \.self) { note in
                    Section(header: Text(note.title).foregroundStyle(currentAccent)) {
                        ForEach(grouped[note]!) { task in
                            Button {
                                selectedNote = task.note
                                toggleTask(task)
                            } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(task.isDone ? Color.green : currentAccent)
                                    Text(task.content).strikethrough(task.isDone).foregroundStyle(task.isDone ? .secondary : .primary)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    private func toggleTask(_ task: GlobalTask) {
        var lines = task.note.content.components(separatedBy: .newlines)
        let line = lines[task.lineIndex]
        lines[task.lineIndex] = line.contains("[ ]") ? line.replacingOccurrences(of: "[ ]", with: "[x]") : line.replacingOccurrences(of: "[x]", with: "[ ]")
        task.note.content = lines.joined(separator: "\n")
        try? task.note.modelContext?.save()
    }
}

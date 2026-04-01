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
    @Query(filter: #Predicate<Note> { $0.isPinned == true })
    private var pinnedNotes: [Note]
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
                bottomAction(icon: "square.and.arrow.down", help: "Import Files") {
                    importAnyFiles()
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
    private func bottomAction(icon: String, help: LocalizedStringKey, action: @escaping () -> Void) -> some View {
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
                            Label(note.title, systemImage: note.fileData != nil ? "doc.append" : "doc.text").foregroundStyle(currentAccent)
                        }
                    }
                }
            } else {
                if !pinnedNotes.isEmpty {
                    Section("Pinned") {
                        ForEach(pinnedNotes) { note in
                            RecursiveNoteView(note: note, currentAccent: currentAccent, selectedNote: $selectedNote, folders: folders, onAddSubnote: {
                                self.noteToCreateSubnoteFor = note
                                self.showingNewNoteSheet = true
                            })
                        }
                    }
                }

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
                            .contextMenu {
                                Button(role: .destructive) { modelContext.delete(folder) } label: { Label("Delete Folder", systemImage: "trash") }
                            }
                            .onDrop(of: [.fileURL], isTargeted: nil) { handleFileDrop($0, into: folder) }
                        }
                    }
                }
                
                Section("Notes") {
                    ForEach(rootNotes.filter { !$0.isPinned }) { note in
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

    private func importAnyFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.item]
        if panel.runModal() == .OK {
            for url in panel.urls { createNoteFromURL(url) }
        }
    }
    
    private func handleFileDrop(_ providers: [NSItemProvider], into folder: Folder? = nil) -> Bool {
        for provider in providers {
            provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    DispatchQueue.main.async { createNoteFromURL(url, into: folder) }
                }
            }
        }
        return true
    }
    
    private func createNoteFromURL(_ url: URL, into folder: Folder? = nil) {
        let fileName = url.deletingPathExtension().lastPathComponent
        let fileExt = url.pathExtension.lowercased()
        
        if fileExt == "md" {
            if let content = try? String(contentsOf: url) {
                let newNote = Note(title: fileName, content: content)
                newNote.folder = folder
                modelContext.insert(newNote)
            }
        } else {
            if let data = try? Data(contentsOf: url) {
                let newNote = Note(title: fileName, content: "", fileData: data, fileExtension: fileExt)
                newNote.folder = folder
                modelContext.insert(newNote)
            }
        }
        try? modelContext.save()
    }
}

struct RecursiveNoteView: View {
    let note: Note
    let currentAccent: Color
    @Binding var selectedNote: Note?
    let folders: [Folder]
    let onAddSubnote: () -> Void
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingDeleteAlert = false

    var iconName: String {
        if let ext = note.fileExtension?.lowercased() {
            switch ext {
            case "pdf": return "doc.richtext"
            case "png", "jpg", "jpeg", "gif": return "photo"
            case "pptx", "ppt": return "doc.presentation"
            case "xls", "xlsx": return "tablecells"
            case "zip", "rar", "7z": return "archivebox"
            default: return "doc.append"
            }
        }
        return note.children.isEmpty ? "doc.text" : "doc.text.fill"
    }

    var body: some View {
        Group {
            if note.children.isEmpty {
                NavigationLink(value: note) {
                    HStack {
                        Label(note.title, systemImage: iconName).foregroundStyle(currentAccent)
                        Spacer()
                        if note.isPinned { Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(.orange) }
                    }
                }
                .contextMenu { noteMenu }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { showingDeleteAlert = true } label: { Image(systemName: "trash") }
                    Button { note.isPinned.toggle() } label: { Image(systemName: note.isPinned ? "pin.slash" : "pin") }.tint(.orange)
                }
                .swipeActions(edge: .leading) {
                    Button { onAddSubnote() } label: { Image(systemName: "plus") }.tint(currentAccent)
                    if note.folder != nil || note.parentNote != nil {
                        Button { moveToRoot() } label: { Image(systemName: "arrow.left.to.line") }.tint(.blue)
                    }
                }
            } else {
                DisclosureGroup {
                    ForEach(note.children.sorted(by: { $0.title < $1.title })) { child in
                        RecursiveNoteView(note: child, currentAccent: currentAccent, selectedNote: $selectedNote, folders: folders, onAddSubnote: onAddSubnote)
                    }
                } label: {
                    NavigationLink(value: note) {
                        HStack {
                            Label(note.title, systemImage: iconName).foregroundStyle(currentAccent)
                            Spacer()
                            if note.isPinned { Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(.orange) }
                        }
                    }
                    .contextMenu { noteMenu }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { showingDeleteAlert = true } label: { Image(systemName: "trash") }
                        Button { note.isPinned.toggle() } label: { Image(systemName: note.isPinned ? "pin.slash" : "pin") }.tint(.orange)
                    }
                    .swipeActions(edge: .leading) {
                        Button { onAddSubnote() } label: { Image(systemName: "plus") }.tint(currentAccent)
                        if note.folder != nil || note.parentNote != nil {
                            Button { moveToRoot() } label: { Image(systemName: "arrow.left.to.line") }.tint(.blue)
                        }
                    }
                }
            }
        }
        .confirmationDialog("Are you sure you want to delete '\(note.title)'?", isPresented: $showingDeleteAlert, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteThisNote() }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private func moveToRoot() {
        note.folder = nil
        note.parentNote = nil
        try? modelContext.save()
    }
    
    private func deleteThisNote() {
        if selectedNote == note { selectedNote = nil }
        modelContext.delete(note)
    }
    
    @ViewBuilder
    var noteMenu: some View {
        Button { note.isPinned.toggle() } label: { Label(note.isPinned ? "Unpin" : "Pin", systemImage: "pin") }
        Button(action: onAddSubnote) { Label("Add Sub-note", systemImage: "arrow.turn.down.right") }
        Divider()
        if note.folder != nil || note.parentNote != nil {
            Button { moveToRoot() } label: { Label("Move to Root", systemImage: "arrow.left.to.line") }
        }
        Menu("Move to Folder...") {
            Button("None (Root)") { note.folder = nil; note.parentNote = nil; try? modelContext.save() }
            ForEach(folders) { folder in
                Button(folder.name) { note.folder = folder; note.parentNote = nil; try? modelContext.save() }
            }
        }
        Divider()
        Button("Delete", role: .destructive) { showingDeleteAlert = true }
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

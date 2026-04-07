import SwiftData
import Foundation

@Model
class Folder: Identifiable, Hashable {
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Note.folder)
    var notes: [Note] = []
    
    init(name: String = "New Folder") {
        self.name = name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    static func == (lhs: Folder, rhs: Folder) -> Bool {
        lhs.id == rhs.id
    }
}

@Model
class Note: Identifiable, Hashable {
    var title: String
    var content: String
    var isPinned: Bool = false
    
    @Attribute(.externalStorage) var fileData: Data?
    var fileExtension: String?
    var lastPDFPage: Int = 0 
    
    var parentNote: Note?
    
    @Relationship(deleteRule: .cascade, inverse: \Note.parentNote)
    var children: [Note] = []
    
    var folder: Folder?
    
    init(title: String = "New note", content: String = "", parentNote: Note? = nil, folder: Folder? = nil, fileData: Data? = nil, fileExtension: String? = nil, lastPDFPage: Int = 0) {
        self.title = title
        self.content = content
        self.parentNote = parentNote
        self.folder = folder
        self.fileData = fileData
        self.fileExtension = fileExtension
        self.isPinned = false
        self.lastPDFPage = lastPDFPage
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }
}

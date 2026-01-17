import SwiftData
import Foundation

@Model
class Note: Identifiable, Hashable {
    var title: String
    var content: String
    var parentNote: Note?
    
    init(title: String = "New note", content: String = "", parentNote: Note? = nil) {
        self.title = title
        self.content = content
        self.parentNote = parentNote
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }
}


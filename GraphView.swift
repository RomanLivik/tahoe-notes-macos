import SwiftUI
import SwiftData

struct GraphView: View {
    @Query private var allNotes: [Note]
    @Binding var selectedNote: Note?
    @AppStorage("app_accent_color") private var appAccentColor = "azure"
    
    @State private var nodePositions: [PersistentIdentifier: CGPoint] = [:]
    
    private var currentAccent: Color {
        AppAccentColor(rawValue: appAccentColor)?.color ?? .cyan
    }
    
    var body: some View {
        GeometryReader { geo in
            let links = calculateLinks()
            
            Canvas { context, size in
                for link in links {
                    if let start = nodePositions[link.source.id],
                       let end = nodePositions[link.target.id] {
                        var path = Path()
                        path.move(to: start)
                        path.addLine(to: end)
                        context.stroke(path, with: .color(currentAccent.opacity(0.2)), lineWidth: 1)
                    }
                }
                
                for note in allNotes {
                    if let pos = nodePositions[note.id] {
                        let isSelected = selectedNote?.id == note.id
                        
                        let radius: CGFloat = isSelected ? 5 : 3
                        let rect = CGRect(x: pos.x - radius, y: pos.y - radius, width: radius * 2, height: radius * 2)
                        
                        context.fill(Path(ellipseIn: rect), with: .color(isSelected ? .primary : currentAccent))
                        
                        if isSelected {
                            context.stroke(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(currentAccent), lineWidth: 1.5)
                        }
                        
                        let resolvedText = context.resolve(
                            Text(note.title)
                                .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                                .foregroundColor(isSelected ? .primary : .secondary)
                        )
                        
                        let textPosition = CGPoint(x: pos.x, y: pos.y + radius + 4)
                        
                        context.draw(resolvedText, at: textPosition, anchor: .top)
                    }
                }
            }
            .onTapGesture { location in
                handleTap(at: location)
            }
            .onAppear { updatePositions(in: geo.size) }
            .onChange(of: allNotes.count) { updatePositions(in: geo.size) }
            .onChange(of: geo.size) { updatePositions(in: geo.size) }
        }
    }
    
    private func handleTap(at location: CGPoint) {
        for (id, pos) in nodePositions {
            let distance = sqrt(pow(pos.x - location.x, 2) + pow(pos.y - location.y, 2))
            if distance < 15 {
                if let targetNote = allNotes.first(where: { $0.id == id }) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selectedNote = targetNote
                    }
                }
                break
            }
        }
    }
    
    private func updatePositions(in size: CGSize) {
        var newPositions: [PersistentIdentifier: CGPoint] = [:]
        let centerX = size.width * 0.35
        let centerY = size.height * 0.5
        let center = CGPoint(x: centerX, y: centerY)
        
        let radius = min(size.width, size.height) * 0.3
        
        for (index, note) in allNotes.enumerated() {
            let angle = 2 * Double.pi * Double(index) / Double(max(1, allNotes.count))
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            newPositions[note.id] = CGPoint(x: x, y: y)
        }
        
        withAnimation(.easeInOut(duration: 0.5)) {
            nodePositions = newPositions
        }
    }
    
    struct NoteLink {
        let source: Note
        let target: Note
    }
    
    private func calculateLinks() -> [NoteLink] {
        var links: [NoteLink] = []
        let wikiPattern = /\[\[(.*?)\]\]/
        
        for sourceNote in allNotes {
            let matches = sourceNote.content.matches(of: wikiPattern)
            for match in matches {
                let targetTitle = String(match.output.1).lowercased()
                if let targetNote = allNotes.first(where: { $0.title.lowercased() == targetTitle }) {
                    links.append(NoteLink(source: sourceNote, target: targetNote))
                }
            }
        }
        return links
    }
}

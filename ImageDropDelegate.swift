import SwiftUI            
import SwiftData
import AppKit
import UniformTypeIdentifiers


struct ImageDropDelegate: DropDelegate {
    let note: Note
    @Binding var images: [String: NSImage]
    
    func performDrop(info: DropInfo) -> Bool {
        for provider in info.itemProviders(for: [.fileURL, .image]) {
            provider.loadObject(ofClass: NSImage.self) { image, _ in
                if let image = image as? NSImage {
                    let imageId = UUID().uuidString.prefix(8)
                    DispatchQueue.main.async {
                        images[String(imageId)] = image
                        note.content += "\n![image-\(imageId)]()\n"
                    }
                }
            }
        }
        return true
    }
}


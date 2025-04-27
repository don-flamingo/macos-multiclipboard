import Foundation
import Cocoa

enum ClipboardItemType: String, Codable {
    case text
    case image
    case webImage
}

struct ClipboardItem: Equatable {
    let id: UUID
    let timestamp: Date
    let type: ClipboardItemType
    let textContent: String?
    let imageContent: NSImage?
    let sourceURL: URL?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), type: ClipboardItemType, textContent: String? = nil, imageContent: NSImage? = nil, sourceURL: URL? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.textContent = textContent
        self.imageContent = imageContent
        self.sourceURL = sourceURL
    }
    
    // Preview text for display
    var previewText: String {
        switch type {
        case .text:
            return textContent ?? ""
        case .image:
            return "[Image]"
        case .webImage:
            return "[Web Image]"
        }
    }
    
    static func fromPasteboard(_ pasteboard: NSPasteboard) -> ClipboardItem? {
        // Try multiple approaches for getting images
        var image: NSImage? = nil
        
        // First try using NSImage's pasteboard initializer
        if let pasteboardImage = NSImage(pasteboard: pasteboard) {
            image = pasteboardImage
        } 
        // Then try looking for specific image types in the pasteboard
        else if let tiffData = pasteboard.data(forType: .tiff), 
                let tiffImage = NSImage(data: tiffData) {
            image = tiffImage
        }
        else if let pngData = pasteboard.data(forType: .png),
                let pngImage = NSImage(data: pngData) {
            image = pngImage
        }
        else if let fileListData = pasteboard.propertyList(forType: .fileURL) as? [String],
                let firstFile = fileListData.first,
                let fileURL = URL(string: firstFile),
                let fileImage = NSImage(contentsOf: fileURL),
                ["png", "jpg", "jpeg", "gif", "tiff", "webp"].contains(fileURL.pathExtension.lowercased()) {
            image = fileImage
        }
        
        // If we found an image through any method
        if let image = image {
            // Check if there's also a URL (might be a web image)
            if let urlString = pasteboard.string(forType: .URL),
               let url = URL(string: urlString) {
                return ClipboardItem(type: .webImage, imageContent: image, sourceURL: url)
            }
            return ClipboardItem(type: .image, imageContent: image)
        }
        
        // Then check for text
        else if let text = pasteboard.string(forType: .string) {
            // Check if the text is a URL
            if let url = URL(string: text), url.scheme != nil {
                return ClipboardItem(type: .text, textContent: text, sourceURL: url)
            }
            return ClipboardItem(type: .text, textContent: text)
        }
        
        return nil
    }
    
    func copyToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch type {
        case .text:
            if let text = textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image, .webImage:
            if let image = imageContent {
                // First, try the standard NSPasteboardWriting protocol
                let result = pasteboard.writeObjects([image])
                
                // If that fails, try a more direct approach with specific types
                if !result {
                    if let tiffData = image.tiffRepresentation {
                        pasteboard.setData(tiffData, forType: .tiff)
                    }
                    
                    // Try to add PNG representation as well
                    if let imgRep = NSBitmapImageRep(data: image.tiffRepresentation ?? Data()),
                       let pngData = imgRep.representation(using: .png, properties: [:]) {
                        pasteboard.setData(pngData, forType: .png)
                    }
                }
                
                // If this was a web image, also put the URL on the pasteboard
                if type == .webImage, let url = sourceURL {
                    pasteboard.setString(url.absoluteString, forType: .URL)
                }
            }
        }
    }
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        return lhs.id == rhs.id
    }
} 
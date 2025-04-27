import Foundation
import Cocoa

enum ClipboardItemType: String, Codable {
    case text
    case image
    case webImage
}

struct ClipboardItem: Equatable, Codable {
    let id: UUID
    let timestamp: Date
    let type: ClipboardItemType
    let textContent: String?
    let imageContent: NSImage?
    let sourceURL: URL?
    
    // Add formatted timestamp properties
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var dateTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
    
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var timeWithSecondsString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
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
    
    // MARK: - Codable implementation
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, type, textContent, imageData, sourceURL
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(type, forKey: .type)
        try container.encode(textContent, forKey: .textContent)
        
        // Convert NSImage to data for serialization
        if let image = imageContent, let tiffData = image.tiffRepresentation {
            try container.encode(tiffData, forKey: .imageData)
        }
        
        try container.encode(sourceURL, forKey: .sourceURL)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        type = try container.decode(ClipboardItemType.self, forKey: .type)
        textContent = try container.decodeIfPresent(String.self, forKey: .textContent)
        sourceURL = try container.decodeIfPresent(URL.self, forKey: .sourceURL)
        
        // Convert data back to NSImage
        if let imageData = try container.decodeIfPresent(Data.self, forKey: .imageData) {
            imageContent = NSImage(data: imageData)
        } else {
            imageContent = nil
        }
    }
} 
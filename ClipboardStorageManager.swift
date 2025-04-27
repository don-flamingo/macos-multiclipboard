import Cocoa

class ClipboardStorageManager {
    static let shared = ClipboardStorageManager()
    
    private let fileURL: URL
    private let cacheDirectoryURL: URL
    
    private init() {
        // Try to use a more reliable location for storage
        let documentsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/ClipboardManagerData")
        cacheDirectoryURL = documentsPath
        fileURL = documentsPath.appendingPathComponent("clipboard_history.json")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: documentsPath.path) {
            try? FileManager.default.createDirectory(at: documentsPath, withIntermediateDirectories: true)
        }
        
        print("ClipboardStorageManager initialized. Storage location: \(fileURL.path)")
    }
    
    func saveItems(_ items: [ClipboardItem]) {
        // Save all items including those with images
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(items)
            try data.write(to: fileURL)
            print("Saved \(items.count) items to disk at \(fileURL.path)")
        } catch {
            print("Error saving clipboard items: \(error.localizedDescription)")
        }
    }
    
    func loadItems() -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("No saved clipboard items found at \(fileURL.path)")
            return []
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let items = try decoder.decode([ClipboardItem].self, from: data)
            print("Loaded \(items.count) items from disk at \(fileURL.path)")
            return items
        } catch {
            print("Error loading clipboard items: \(error.localizedDescription)")
            return []
        }
    }
    
    func clearAllItems() {
        do {
            // 1. Delete the history JSON file
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("Deleted clipboard history file")
            }
            
            // 2. Create a fresh empty file
            saveItems([])
            
            print("Clipboard history cleared successfully")
        } catch {
            print("Error clearing clipboard items: \(error.localizedDescription)")
        }
    }
} 
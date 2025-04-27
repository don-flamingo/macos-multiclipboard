import Cocoa

class ClipboardStorageManager {
    static let shared = ClipboardStorageManager()
    
    private let fileURL: URL
    
    private init() {
        // Try to use a more reliable location for storage
        let customPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/ClipboardManagerData/clipboard_history.json")
        fileURL = customPath
        
        // Create directory if it doesn't exist
        let directoryPath = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directoryPath.path) {
            try? FileManager.default.createDirectory(at: directoryPath, withIntermediateDirectories: true)
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
} 
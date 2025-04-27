import Foundation

struct ClipboardItem: Equatable {
    let id = UUID()
    let content: String
    let timestamp: Date
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        return lhs.id == rhs.id
    }
} 
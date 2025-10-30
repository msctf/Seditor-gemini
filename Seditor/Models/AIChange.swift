import Foundation

struct PendingChange: Codable, Hashable {
    var edits: [CodeEditOperation]
    var fullContent: String?

    init(edits: [CodeEditOperation] = [], fullContent: String? = nil) {
        self.edits = edits
        self.fullContent = fullContent
    }
}


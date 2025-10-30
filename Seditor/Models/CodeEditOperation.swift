import Foundation

struct CodeEditOperation: Codable, Hashable {
    let startLine: Int
    let endLine: Int
    let replacement: String

    enum CodingKeys: String, CodingKey {
        case startLine = "start_line"
        case endLine = "end_line"
        case replacement
    }
}


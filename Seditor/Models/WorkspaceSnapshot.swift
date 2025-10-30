import Foundation

struct WorkspaceSnapshot: Codable {
    var id: UUID
    var name: String
    var files: [CodeFile]
    var folders: [CodeFolder]
    var selectedFileID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        files: [CodeFile],
        folders: [CodeFolder],
        selectedFileID: UUID?,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.files = files
        self.folders = folders
        self.selectedFileID = selectedFileID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

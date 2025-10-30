import Foundation

struct ProjectMetadata: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func updating(name: String? = nil, updatedAt: Date? = nil) -> ProjectMetadata {
        ProjectMetadata(
            id: id,
            name: name ?? self.name,
            createdAt: createdAt,
            updatedAt: updatedAt ?? self.updatedAt
        )
    }

    init(snapshot: WorkspaceSnapshot) {
        self.init(
            id: snapshot.id,
            name: snapshot.name,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt
        )
    }
}

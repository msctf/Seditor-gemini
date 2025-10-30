import Foundation

final class ProjectStore {
    static let shared = ProjectStore()

    private let baseDirectory: URL
    private let metadataFileName = "metadata.json"
    private let workspaceFileName = "workspace.json"
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted]

        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.baseDirectory = documents.appendingPathComponent("SeditorProjects", isDirectory: true)

        do {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        } catch {
            assertionFailure("Unable to create projects directory: \(error)")
        }
    }

    func ensureProjectDirectoryExists() throws {
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    func loadProjects() -> [ProjectMetadata] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var projects: [ProjectMetadata] = []
        for directory in contents {
            guard isDirectory(url: directory) else { continue }
            let metadataURL = directory.appendingPathComponent(metadataFileName, isDirectory: false)
            guard fileManager.fileExists(atPath: metadataURL.path),
                  let data = try? Data(contentsOf: metadataURL),
                  let metadata = try? decoder.decode(ProjectMetadata.self, from: data) else { continue }
            projects.append(metadata)
        }

        return projects.sorted { $0.updatedAt > $1.updatedAt }
    }

    func loadProject(by id: UUID) -> WorkspaceSnapshot? {
        let workspaceURL = workspaceURL(for: id)
        guard fileManager.fileExists(atPath: workspaceURL.path),
              let data = try? Data(contentsOf: workspaceURL),
              let snapshot = try? decoder.decode(WorkspaceSnapshot.self, from: data) else { return nil }
        return snapshot
    }

    func save(snapshot: WorkspaceSnapshot) throws -> WorkspaceSnapshot {
        var mutableSnapshot = snapshot
        mutableSnapshot.updatedAt = Date()
        let directory = projectDirectory(for: mutableSnapshot.id)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let workspaceURL = directory.appendingPathComponent(workspaceFileName, isDirectory: false)
        let data = try encoder.encode(mutableSnapshot)
        try data.write(to: workspaceURL, options: .atomic)
        let metadata = ProjectMetadata(snapshot: mutableSnapshot)
        try persist(metadata: metadata, at: directory)
        return mutableSnapshot
    }

    func createProject(named name: String) throws -> WorkspaceSnapshot {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "Untitled Project" : trimmed
        let snapshot = WorkspaceSnapshot(
            name: fallback,
            files: [],
            folders: [],
            selectedFileID: nil
        )
        let directory = projectDirectory(for: snapshot.id)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let saved = try save(snapshot: snapshot)
        return saved
    }

    func rename(project id: UUID, to name: String) throws -> ProjectMetadata? {
        guard var snapshot = loadProject(by: id) else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ProjectMetadata(snapshot: snapshot)
        }
        snapshot.name = trimmed
        snapshot.updatedAt = Date()
        let saved = try save(snapshot: snapshot)
        return ProjectMetadata(snapshot: saved)
    }

    func delete(project id: UUID) throws {
        let directory = projectDirectory(for: id)
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
    }

    private func projectDirectory(for id: UUID) -> URL {
        baseDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func workspaceURL(for id: UUID) -> URL {
        projectDirectory(for: id).appendingPathComponent(workspaceFileName, isDirectory: false)
    }

    private func persist(metadata: ProjectMetadata, at directory: URL) throws {
        let metadataURL = directory.appendingPathComponent(metadataFileName, isDirectory: false)
        let data = try encoder.encode(metadata)
        try data.write(to: metadataURL, options: .atomic)
    }

    private func isDirectory(url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]) else { return false }
        return values.isDirectory == true
    }
}

import SwiftUI
import Combine
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var files: [CodeFile] { didSet { scheduleWorkspaceSave() } }
    @Published var folders: [CodeFolder] { didSet { scheduleWorkspaceSave() } }
    @Published var selectedFileID: UUID? { didSet { scheduleWorkspaceSave() } }
    @Published var isShowingNewFileSheet = false
    @Published var isShowingPreview = false
    @Published var isShowingImporter = false
    @Published var isShowingFolderSheet = false
    @Published var isMenuVisible = false
    @Published var alertMessage: String?
    @Published var isShowingAI = false
    @Published var editorPreferences = EditorPreferences()
    @Published var pendingFolderForNewFile: CodeFolder?
    @Published var aiSettings: AISettings
    @Published var projects: [ProjectMetadata] = []
    @Published var currentProject: ProjectMetadata? {
        didSet {
            guard let project = currentProject else { return }
            UserDefaults.standard.set(project.id.uuidString, forKey: lastProjectDefaultsKey)
        }
    }
    @Published var isShowingProjectManager = false

    private let aiDefaultsKey = "ai.settings.preferences"
    private let aiKeychainService = "com.seditor.ai"
    private let aiKeychainAccount = "api.key"
    private let lastProjectDefaultsKey = "workspace.lastProject.id"
    private let legacyWorkspaceFileName = "workspace.json"
    private let projectStore = ProjectStore.shared
    private var isLoadingWorkspace = false
    private var saveWorkItem: DispatchWorkItem?

    init(files: [CodeFile]? = nil, folders: [CodeFolder] = []) {
        let initialFiles = files ?? CodeFile.demoFiles
        isLoadingWorkspace = true
        self.files = initialFiles
        self.folders = folders
        self.selectedFileID = initialFiles.first?.id
        isLoadingWorkspace = false
        self.aiSettings = AISettings.default
        loadAISettings()
        configureInitialProject(defaultFiles: initialFiles, defaultFolders: folders)
    }

    var selectedFile: CodeFile? {
        guard let id = selectedFileID else { return nil }
        return files.first { $0.id == id }
    }

    var selectedFileBinding: Binding<CodeFile>? {
        guard let id = selectedFileID,
              let index = files.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: { self.files[index] },
            set: { self.files[index] = $0 }
        )
    }

    var metrics: [Metric] {
        [
            Metric(label: "Files", value: "\(files.count)", icon: "folder", accent: .accentBlue),
            Metric(label: "Total Lines", value: "\(files.reduce(0) { $0 + $1.content.lineCount })", icon: "number.square", accent: .accentPurple),
            Metric(label: "Characters", value: "\(files.reduce(0) { $0 + $1.content.count })", icon: "textformat.abc", accent: .accentCyan),
            Metric(label: "Preview Ready", value: isPreviewReady ? "Yes" : "Add HTML", icon: "bolt.fill", accent: .accentOrange)
        ]
    }

    var combinedHTML: String {
        let html = htmlDocument
        let css = cssBlock
        let js = javascriptBlock

        return """
        <!DOCTYPE html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \(css)
          </head>
          <body>
            \(html)
            \(js)
          </body>
        </html>
        """
    }

    func selectFile(_ file: CodeFile) {
        selectedFileID = file.id
        if isMenuVisible {
            toggleMenu(show: false)
        }
        if isShowingPreview {
            isShowingPreview = false
        }
    }

    func toggleNewFileSheet(show: Bool) {
        isShowingNewFileSheet = show
        if !show {
            pendingFolderForNewFile = nil
        }
    }

    func togglePreview(show: Bool) {
        isShowingPreview = show
    }

    func toggleImporter(show: Bool) {
        isShowingImporter = show
    }

    func toggleFolderSheet(show: Bool) {
        isShowingFolderSheet = show
    }

    func toggleMenu(show: Bool? = nil) {
        let targetState: Bool
        if let show {
            targetState = show
        } else {
            targetState = isMenuVisible == false
        }

        if targetState {
            dismissKeyboard()
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isMenuVisible = targetState
        }
    }

    func openNewFile(in folder: CodeFolder?) {
        pendingFolderForNewFile = folder
        toggleMenu(show: false)
        toggleNewFileSheet(show: true)
    }

    func createProject(named name: String, includeStarter: Bool = false) {
        do {
            var snapshot = try projectStore.createProject(named: name)
            if includeStarter {
                snapshot.files = CodeFile.starterProject
                snapshot.selectedFileID = snapshot.files.first?.id
            }
            let savedSnapshot = try projectStore.save(snapshot: snapshot)
            apply(snapshot: savedSnapshot)
            isShowingProjectManager = false
        } catch {
            alertMessage = "Gagal membuat project: \(error.localizedDescription)"
        }
    }

    func selectProject(_ project: ProjectMetadata) {
        guard project.id != currentProject?.id else {
            isShowingProjectManager = false
            return
        }
        flushPendingSave()
        guard let snapshot = projectStore.loadProject(by: project.id) else {
            alertMessage = "Gagal membuka project yang dipilih."
            return
        }
        apply(snapshot: snapshot)
        isShowingProjectManager = false
    }

    func deleteProject(_ project: ProjectMetadata) {
        guard project.id != currentProject?.id else {
            alertMessage = "Tutup project ini sebelum menghapusnya."
            return
        }
        do {
            try projectStore.delete(project: project.id)
            projects.removeAll { $0.id == project.id }
        } catch {
            alertMessage = "Gagal menghapus project: \(error.localizedDescription)"
        }
    }

    func renameCurrentProject(to name: String) {
        guard let currentProject else { return }
        flushPendingSave()
        do {
            guard let metadata = try projectStore.rename(project: currentProject.id, to: name) else { return }
            DispatchQueue.main.async {
                self.currentProject = metadata
                self.refreshProjects(with: metadata)
            }
        } catch {
            alertMessage = "Gagal mengganti nama project: \(error.localizedDescription)"
        }
    }

    func appendFile(_ file: CodeFile, to folder: CodeFolder? = nil) {
        var newFile = file
        newFile.folderID = folder?.id ?? newFile.folderID
        files.append(newFile)
        selectedFileID = newFile.id
        isShowingPreview = false
    }

    func renameFile(_ file: CodeFile, to newName: String) {
        guard let index = files.firstIndex(of: file) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            alertMessage = "Nama file tidak boleh kosong."
            return
        }
        files[index].name = trimmed
    }

    func duplicateFile(_ file: CodeFile) {
        guard let index = files.firstIndex(of: file) else { return }
        let duplicateName = uniqueDuplicateName(for: file)
        let duplicate = CodeFile(name: duplicateName, language: file.language, content: file.content, folderID: file.folderID)
        files.insert(duplicate, at: files.index(after: index))
        selectedFileID = duplicate.id
        isShowingPreview = false
    }

    func deleteFile(_ file: CodeFile) {
        guard let index = files.firstIndex(of: file) else { return }
        files.remove(at: index)
        if files.isEmpty {
            selectedFileID = nil
        } else if selectedFileID == file.id {
            let nextIndex = min(index, files.count - 1)
            selectedFileID = files[nextIndex].id
        }
        isShowingPreview = false
    }

    func loadStarterTemplate() {
        var updated = files
        for sample in CodeFile.starterProject {
            let exists = updated.contains { $0.name == sample.name && $0.folderID == sample.folderID }
            if !exists {
                updated.append(sample)
            }
        }
        files = updated
        selectedFileID = files.first?.id
        isShowingPreview = false
        toggleMenu(show: false)
    }

    func applyGeneratedChange(_ change: PendingChange) {
        guard let id = selectedFileID,
              let index = files.firstIndex(where: { $0.id == id }) else { return }

        if let full = change.fullContent {
            files[index].content = full
            return
        }

        guard change.edits.isEmpty == false else { return }

        var lines = files[index].content.components(separatedBy: "\n")
        let sorted = change.edits.sorted { $0.startLine > $1.startLine }

        for edit in sorted {
            let clampedStart = min(max(edit.startLine, 1), lines.count + 1)
            let clampedEnd = min(max(edit.endLine, clampedStart - 1), lines.count)
            let replacementLines = edit.replacement.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

            if clampedEnd >= clampedStart {
                let lower = max(clampedStart - 1, 0)
                let upper = max(clampedEnd - 1, lower)
                if lower < lines.count {
                    let safeUpper = min(upper, lines.count - 1)
                    lines.replaceSubrange(lower...safeUpper, with: replacementLines)
                } else if lower == lines.count {
                    lines.append(contentsOf: replacementLines)
                }
            } else {
                let insertionIndex = min(max(clampedStart - 1, 0), lines.count)
                lines.insert(contentsOf: replacementLines, at: insertionIndex)
            }
        }

        files[index].content = lines.joined(separator: "\n")
    }

    func saveAISettings(_ settings: AISettings) {
        aiSettings = settings
        let defaults = UserDefaults.standard
        defaults.set(settings.model, forKey: "\(aiDefaultsKey).model")
        defaults.set(settings.temperature, forKey: "\(aiDefaultsKey).temperature")
        defaults.set(settings.topP, forKey: "\(aiDefaultsKey).topP")
        do {
            try KeychainHelper.save(settings.apiKey, service: aiKeychainService, account: aiKeychainAccount)
        } catch {
            alertMessage = "Gagal menyimpan API key: \(error.localizedDescription)"
        }
    }

    private func loadAISettings() {
        let defaults = UserDefaults.standard
        var settings = AISettings.default
        if let model = defaults.string(forKey: "\(aiDefaultsKey).model") {
            settings.model = model
        }
        let temp = defaults.double(forKey: "\(aiDefaultsKey).temperature")
        if temp != 0 {
            settings.temperature = temp
        }
        let topP = defaults.double(forKey: "\(aiDefaultsKey).topP")
        if topP != 0 {
            settings.topP = topP
        }
        if let apiKey = (try? KeychainHelper.read(service: aiKeychainService, account: aiKeychainAccount)) ?? nil {
            settings.apiKey = apiKey
        }
        aiSettings = settings
    }

    func resetContents(of file: CodeFile) {
        guard let index = files.firstIndex(of: file) else { return }
        files[index].content = files[index].language.template
    }

    func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            alertMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            importFile(at: url)
        }
    }

    private func importFile(at url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            guard let content = normalizeContent(from: data) else {
                alertMessage = "Unsupported file encoding."
                return
            }
            let ext = url.pathExtension.lowercased()
            let language = CodeLanguage.guess(from: ext) ?? .html
            let file = CodeFile(name: url.lastPathComponent, language: language, content: content)
            appendFile(file)
        } catch {
            alertMessage = "Failed to import file: \(error.localizedDescription)"
        }
    }

    private func uniqueDuplicateName(for file: CodeFile) -> String {
        let nsName = file.name as NSString
        let base = nsName.deletingPathExtension
        let ext = nsName.pathExtension
        var counter = 1

        func candidateName() -> String {
            let suffix = counter == 1 ? " copy" : " copy \(counter)"
            if ext.isEmpty {
                return base + suffix
            } else {
                return base + suffix + "." + ext
            }
        }

        var proposed = candidateName()
        while files.contains(where: { $0.folderID == file.folderID && $0.name == proposed }) {
            counter += 1
            proposed = candidateName()
        }
        return proposed
    }

    func createFolder(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folders.append(CodeFolder(name: trimmed))
    }

    func files(in folder: CodeFolder) -> [CodeFile] {
        files.filter { $0.folderID == folder.id }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var looseFiles: [CodeFile] {
        files.filter { $0.folderID == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func assign(file: CodeFile, to folder: CodeFolder?) {
        guard let index = files.firstIndex(of: file) else { return }
        files[index].folderID = folder?.id
    }

    var folderOptions: [CodeFolder] {
        folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var canPreview: Bool {
        isPreviewReady
    }

    private func configureInitialProject(defaultFiles: [CodeFile], defaultFolders: [CodeFolder]) {
        do {
            try projectStore.ensureProjectDirectoryExists()
        } catch {
            alertMessage = "Gagal membuat direktori project: \(error.localizedDescription)"
        }

        if let migrated = migrateLegacyWorkspaceIfNeeded() {
            apply(snapshot: migrated)
            projects = projectStore.loadProjects()
            return
        }

        let existing = projectStore.loadProjects()
        projects = existing

        if
            let lastIDString = UserDefaults.standard.string(forKey: lastProjectDefaultsKey),
            let lastID = UUID(uuidString: lastIDString),
            let snapshot = projectStore.loadProject(by: lastID)
        {
            apply(snapshot: snapshot)
            return
        }

        if let metadata = existing.first,
           let snapshot = projectStore.loadProject(by: metadata.id) {
            apply(snapshot: snapshot)
            return
        }

        do {
            var snapshot = try projectStore.createProject(named: "My Project")
            snapshot.files = defaultFiles
            snapshot.folders = defaultFolders
            snapshot.selectedFileID = defaultFiles.first?.id ?? snapshot.selectedFileID
            let saved = try projectStore.save(snapshot: snapshot)
            apply(snapshot: saved)
            projects = projectStore.loadProjects()
        } catch {
            alertMessage = "Gagal menyiapkan project baru: \(error.localizedDescription)"
            applyTemporaryDefaults(files: defaultFiles, folders: defaultFolders)
        }
    }

    private func apply(snapshot: WorkspaceSnapshot) {
        isLoadingWorkspace = true
        defer { isLoadingWorkspace = false }
        files = snapshot.files
        folders = snapshot.folders
        selectedFileID = snapshot.selectedFileID ?? snapshot.files.first?.id
        let metadata = ProjectMetadata(snapshot: snapshot)
        currentProject = metadata
        refreshProjects(with: metadata)
    }

    private func applyTemporaryDefaults(files defaultFiles: [CodeFile], folders defaultFolders: [CodeFolder]) {
        isLoadingWorkspace = true
        defer { isLoadingWorkspace = false }
        files = defaultFiles
        folders = defaultFolders
        selectedFileID = defaultFiles.first?.id
        currentProject = nil
        projects = []
    }

    private func refreshProjects(with metadata: ProjectMetadata) {
        if let index = projects.firstIndex(where: { $0.id == metadata.id }) {
            projects[index] = metadata
        } else {
            projects.append(metadata)
        }
        projects.sort { $0.updatedAt > $1.updatedAt }
    }

    private func makeSnapshot(for project: ProjectMetadata) -> WorkspaceSnapshot {
        let buildSnapshot = {
            WorkspaceSnapshot(
                id: project.id,
                name: project.name,
                files: self.files,
                folders: self.folders,
                selectedFileID: self.selectedFileID,
                createdAt: project.createdAt
            )
        }
        if Thread.isMainThread {
            return buildSnapshot()
        } else {
            return DispatchQueue.main.sync(execute: buildSnapshot)
        }
    }

    private func migrateLegacyWorkspaceIfNeeded() -> WorkspaceSnapshot? {
        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let legacyURL = documents.appendingPathComponent(legacyWorkspaceFileName, isDirectory: false)
        guard fileManager.fileExists(atPath: legacyURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: legacyURL)
            let legacy = try JSONDecoder().decode(LegacyWorkspaceSnapshot.self, from: data)
            let snapshot = WorkspaceSnapshot(
                name: "Workspace Lama",
                files: legacy.files,
                folders: legacy.folders,
                selectedFileID: legacy.selectedFileID
            )
            let saved = try projectStore.save(snapshot: snapshot)
            try fileManager.removeItem(at: legacyURL)
            return saved
        } catch {
            alertMessage = "Migrasi workspace lama gagal: \(error.localizedDescription)"
            return nil
        }
    }

    private func normalizeContent(from data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8.replacingOccurrences(of: "\r\n", with: "\n")
        }
        if let ascii = String(data: data, encoding: .ascii) {
            return ascii.replacingOccurrences(of: "\r\n", with: "\n")
        }
        return nil
    }

    private func scheduleWorkspaceSave() {
        guard isLoadingWorkspace == false,
              currentProject != nil else { return }
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.persistWorkspace()
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func persistWorkspace() {
        guard let project = currentProject else { return }
        let snapshot = makeSnapshot(for: project)
        let store = projectStore
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                let savedSnapshot = try store.save(snapshot: snapshot)
                let metadata = ProjectMetadata(snapshot: savedSnapshot)
                DispatchQueue.main.async {
                    self?.currentProject = metadata
                    self?.refreshProjects(with: metadata)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.alertMessage = "Gagal menyimpan workspace: \(error.localizedDescription)"
                }
            }
        }
    }


    private func flushPendingSave() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        guard currentProject != nil else { return }
        persistWorkspace()
    }

#if canImport(UIKit)
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
#else
    private func dismissKeyboard() { }
#endif

    private var htmlDocument: String {
        guard let html = files.first(where: { $0.language == .html })?.content,
              html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return """
            <main style="display:grid;place-items:center;min-height:70vh;color:#d0d0d6;font-family:-apple-system,system-ui;">
              <section style="text-align:center;max-width:480px;">
                <h1 style="font-size:2.4rem;margin-bottom:0.5rem;">Add an HTML file</h1>
                <p style="opacity:0.6;">Create or import HTML to see your live preview here.</p>
              </section>
            </main>
            """
        }
        return html
    }

    private var cssBlock: String {
        guard let css = files.first(where: { $0.language == .css })?.content,
              css.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return ""
        }
        return """
        <style>
        \(css)
        </style>
        """
    }

    private var javascriptBlock: String {
        guard let js = files.first(where: { $0.language == .javascript })?.content,
              js.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return ""
        }
        return """
        <script>
        \(js)
        </script>
        """
    }

    private var isPreviewReady: Bool {
        guard let html = files.first(where: { $0.language == .html })?.content else { return false }
        return html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

private struct LegacyWorkspaceSnapshot: Codable {
    var files: [CodeFile]
    var folders: [CodeFolder]
    var selectedFileID: UUID?
}

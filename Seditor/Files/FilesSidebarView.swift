import SwiftUI

struct FilesSidebarView: View {
    let folders: [CodeFolder]
    let looseFiles: [CodeFile]
    let filesProvider: (CodeFolder) -> [CodeFile]
    let selectedID: UUID?
    let currentProjectName: String?
    let activeFile: CodeFile?
    let inlinePreviewAvailable: Bool
    let onSelectFile: (CodeFile) -> Void
    let onCreateFile: (CodeFolder?) -> Void
    let onCreateFolder: () -> Void
    let onImport: () -> Void
    let onLoadTemplate: () -> Void
    let onManageProjects: () -> Void
    let onOpenAI: () -> Void
    let onOpenPreview: () -> Void
    let onRenameFile: (CodeFile, String) -> Void
    let onDuplicateFile: (CodeFile) -> Void
    let onDeleteFile: (CodeFile) -> Void
    let onClose: () -> Void
    let showsCloseButton: Bool
    @Binding var preferences: EditorPreferences

    private enum SidebarPane: String, CaseIterable, Identifiable {
        case files
        case actions
        case references
        case settings

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .files: return "square.grid.2x2"
            case .actions: return "wand.and.stars"
            case .references: return "book"
            case .settings: return "gearshape"
            }
        }

        var label: String {
            switch self {
            case .files: return "Daftar file"
            case .actions: return "Aksi cepat"
            case .references: return "Referensi"
            case .settings: return "Pengaturan"
            }
        }

        var accent: Color {
            switch self {
            case .files: return .accentBlue
            case .actions: return .accentPurple
            case .references: return .accentCyan
            case .settings: return .accentOrange
            }
        }
    }

    @State private var expandedFolders: Set<UUID> = []
    @State private var renamingFileID: UUID?
    @State private var renameDraft: String = ""
    @State private var renameError: String?
    @State private var pendingDelete: CodeFile?
    @FocusState private var renameFieldFocused: Bool

    init(
        folders: [CodeFolder],
        looseFiles: [CodeFile],
        filesProvider: @escaping (CodeFolder) -> [CodeFile],
        selectedID: UUID?,
        currentProjectName: String?,
        activeFile: CodeFile?,
        inlinePreviewAvailable: Bool,
        onSelectFile: @escaping (CodeFile) -> Void,
        onCreateFile: @escaping (CodeFolder?) -> Void,
        onCreateFolder: @escaping () -> Void,
        onImport: @escaping () -> Void,
        onLoadTemplate: @escaping () -> Void,
        onManageProjects: @escaping () -> Void,
        onOpenAI: @escaping () -> Void,
        onOpenPreview: @escaping () -> Void,
        onRenameFile: @escaping (CodeFile, String) -> Void,
        onDuplicateFile: @escaping (CodeFile) -> Void,
        onDeleteFile: @escaping (CodeFile) -> Void,
        onClose: @escaping () -> Void,
        showsCloseButton: Bool = true,
        preferences: Binding<EditorPreferences>
    ) {
        self.folders = folders
        self.looseFiles = looseFiles
        self.filesProvider = filesProvider
        self.selectedID = selectedID
        self.currentProjectName = currentProjectName
        self.activeFile = activeFile
        self.inlinePreviewAvailable = inlinePreviewAvailable
        self.onSelectFile = onSelectFile
        self.onCreateFile = onCreateFile
        self.onCreateFolder = onCreateFolder
        self.onImport = onImport
        self.onLoadTemplate = onLoadTemplate
        self.onManageProjects = onManageProjects
        self.onOpenAI = onOpenAI
        self.onOpenPreview = onOpenPreview
        self.onRenameFile = onRenameFile
        self.onDuplicateFile = onDuplicateFile
        self.onDeleteFile = onDeleteFile
        self.onClose = onClose
        self.showsCloseButton = showsCloseButton
        self._preferences = preferences
    }

    @State private var activePane: SidebarPane = .files

    var body: some View {
        GeometryReader { geo in
            let width = sidebarWidth(for: geo.size.width)

            HStack(alignment: .top, spacing: 16) {
                paneSelector
                    .frame(width: 52)
                VStack(alignment: .leading, spacing: 16) {
                    header
                    Divider().overlay(Color.white.opacity(0.05))
                    paneContent(for: activePane)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(width: width, height: geo.size.height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DashboardTheme.panelBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(DashboardTheme.outline, lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .onAppear {
            expandedFolders = Set(folders.map(\.id))
        }
        .onChange(of: folders) { _ in
            expandedFolders.formUnion(folders.map(\.id))
        }
        .onChange(of: selectedID) { _ in
            if renamingFileID != selectedID {
                cancelRename()
            } else if let file = activeFile {
                renameDraft = file.name
            }
        }
        .onChange(of: activePane) { pane in
            if pane != .files {
                cancelRename()
            }
        }
        .alert("Hapus File?", isPresented: .init(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Hapus", role: .destructive) {
                if let file = pendingDelete { onDeleteFile(file) }
                pendingDelete = nil
            }
            Button("Batal", role: .cancel) { pendingDelete = nil }
        } message: {
            if let file = pendingDelete {
                Text("File \(file.name) akan dihapus permanen.")
            } else {
                Text("File akan dihapus permanen.")
            }
        }
    }

    private func sidebarWidth(for containerWidth: CGFloat) -> CGFloat {
        let spec = layoutSpec(for: activePane, containerWidth: containerWidth)
        let scaledWidth = containerWidth * spec.proportion
        let widthAfterMinClamp = max(scaledWidth, spec.minWidth)
        let clampedToContainer = min(widthAfterMinClamp, containerWidth)
        return min(clampedToContainer, spec.maxWidth)
    }

    private struct SidebarLayoutSpec {
        let minWidth: CGFloat
        let maxWidth: CGFloat
        let proportion: CGFloat
    }

    private func layoutSpec(for pane: SidebarPane, containerWidth: CGFloat) -> SidebarLayoutSpec {
        switch pane {
        case .files:
            let minWidth: CGFloat = showsCloseButton ? 340 : 360
            let maxWidth = min(containerWidth, 440)
            let proportion: CGFloat = showsCloseButton ? 0.9 : 0.94
            return SidebarLayoutSpec(minWidth: minWidth, maxWidth: maxWidth, proportion: proportion)
        case .actions:
            let minWidth: CGFloat = 260
            let maxWidth = min(containerWidth, 320)
            let proportion: CGFloat = showsCloseButton ? 0.72 : 0.78
            return SidebarLayoutSpec(minWidth: minWidth, maxWidth: maxWidth, proportion: proportion)
        case .references:
            let minWidth: CGFloat = 260
            let maxWidth = min(containerWidth, 320)
            let proportion: CGFloat = showsCloseButton ? 0.7 : 0.76
            return SidebarLayoutSpec(minWidth: minWidth, maxWidth: maxWidth, proportion: proportion)
        case .settings:
            let minWidth: CGFloat = 300
            let maxWidth = min(containerWidth, 380)
            let proportion: CGFloat = showsCloseButton ? 0.8 : 0.86
            return SidebarLayoutSpec(minWidth: minWidth, maxWidth: maxWidth, proportion: proportion)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Workspace")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DashboardTheme.textPrimary)
                if let name = currentProjectName {
                    Text(name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                }
                Text("Kelola file dan folder projekmu.")
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.textSecondary)
            }
            Spacer()
            if showsCloseButton {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DashboardTheme.textSecondary)
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionHeader(title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.white.opacity(0.6))
            .padding(.horizontal, 4)
    }

    private var paneSelector: some View {
        VStack(spacing: 12) {
            ForEach(mainPanes) { pane in
                let isActive = pane == activePane
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        activePane = pane
                    }
                } label: {
                    Image(systemName: pane.icon)
                        .font(.headline.weight(.semibold))
                        .frame(width: 42, height: 42)
                        .foregroundStyle(isActive ? Color.black.opacity(0.88) : Color.white.opacity(0.8))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isActive ? pane.accent.opacity(0.92) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isActive ? pane.accent.opacity(0.9) : Color.white.opacity(0.08), lineWidth: isActive ? 1.2 : 0.8)
                        )
                        .shadow(color: isActive ? pane.accent.opacity(0.35) : .clear, radius: 9, y: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(pane.label)
                .accessibilityHint("Tampilkan \(pane.label.lowercased()).")
            }
            Spacer()
            settingsSelectorButton
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var mainPanes: [SidebarPane] {
        SidebarPane.allCases.filter { $0 != .settings }
    }

    private var settingsSelectorButton: some View {
        let pane = SidebarPane.settings
        let isActive = pane == activePane
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                activePane = pane
            }
        } label: {
            Image(systemName: pane.icon)
                .font(.headline.weight(.semibold))
                .frame(width: 42, height: 42)
                .foregroundStyle(isActive ? Color.black.opacity(0.88) : Color.white.opacity(0.8))
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isActive ? pane.accent.opacity(0.92) : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isActive ? pane.accent.opacity(0.9) : Color.white.opacity(0.08), lineWidth: isActive ? 1.2 : 0.8)
                )
                .shadow(color: isActive ? pane.accent.opacity(0.35) : .clear, radius: 9, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pane.label)
        .accessibilityHint("Buka pengaturan editor.")
    }

    @ViewBuilder
    private func paneContent(for pane: SidebarPane) -> some View {
        switch pane {
        case .files:
            filesPane
        case .actions:
            actionsPane
        case .references:
            referencesPane
        case .settings:
            settingsPane
        }
    }

    private var iconGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 52, maximum: 72), spacing: 12)]
    }

    private var filesPane: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader(title: "Daftar File")
                folderSection
                looseFilesSection

                if folders.isEmpty && looseFiles.isEmpty {
                    Text("Belum ada file. Gunakan tombol aksi untuk mulai membuat atau mengimpor file.")
                        .font(.footnote)
                        .foregroundStyle(DashboardTheme.textSecondary)
                        .padding(.top, 6)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var actionsPane: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader(title: "Kelola File")
                LazyVGrid(columns: iconGridColumns, spacing: 12) {
                    iconWidgetButton(icon: "doc.badge.plus", tint: .accentPurple, label: "File Baru") {
                        onCreateFile(nil)
                    }
                    iconWidgetButton(icon: "folder.badge.plus", tint: .accentBlue, label: "Folder Baru") {
                        onCreateFolder()
                    }
                    iconWidgetButton(icon: "tray.and.arrow.down", tint: .accentCyan, label: "Impor File") {
                        onImport()
                    }
                    iconWidgetButton(icon: "shippingbox.and.arrow.down", tint: .accentYellow, label: "Load Template") {
                        onLoadTemplate()
                    }
                    if let file = activeFile {
                        iconWidgetButton(icon: "square.on.square", tint: file.language.accentColor, label: "Duplikat File Aktif") {
                            onDuplicateFile(file)
                        }
                        iconWidgetButton(icon: "trash", tint: .red.opacity(0.9), label: "Hapus File Aktif") {
                            handleDelete(file)
                        }
                    }
                }

                Divider().overlay(Color.white.opacity(0.05))

                sectionHeader(title: "Workspace & Tools")
                LazyVGrid(columns: iconGridColumns, spacing: 12) {
                    iconWidgetButton(icon: "folder.fill.badge.gearshape", tint: .accentOrange, label: "Kelola Project") {
                        onManageProjects()
                    }
                    iconWidgetButton(icon: "sparkles", tint: .accentPurple.opacity(0.85), label: "Beri Instruksi ke AI") {
                        onOpenAI()
                    }
                    if inlinePreviewAvailable {
                        iconStatusTile(icon: "rectangle.split.3x1", tint: .accentTeal, label: "Preview otomatis aktif")
                    } else {
                        iconWidgetButton(
                            icon: "play.rectangle",
                            tint: .accentTeal,
                            label: "Lihat Preview",
                            disabled: activeFile == nil
                        ) {
                            onOpenPreview()
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var referencesPane: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader(title: "Referensi")
                LazyVGrid(columns: iconGridColumns, spacing: 12) {
                    iconStatusTile(icon: "questionmark.circle", tint: .accentBlue, label: "Panduan Penggunaan", showsStatus: false)
                    iconStatusTile(icon: "keyboard", tint: .accentCyan, label: "Shortcut Keyboard", showsStatus: false)
                    iconStatusTile(icon: "lifepreserver", tint: .accentPurple, label: "Hubungi Support", showsStatus: false)
                }

                sectionHeader(title: "Tips Singkat")
                LazyVGrid(columns: iconGridColumns, spacing: 12) {
                    iconStatusTile(icon: "square.stack.3d.up", tint: .accentBlue, label: "Gunakan folder untuk memisahkan komponen")
                    iconStatusTile(icon: "clock.arrow.circlepath", tint: .accentYellow, label: "Simpan versi penting sebelum pakai AI")
                    iconStatusTile(icon: "rectangle.split.3x1.fill", tint: .accentTeal, label: "Aktifkan preview di layar lebar")
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var settingsPane: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Sesuaikan preferensi editor tanpa menutup workspace kamu.")
                    .font(.footnote)
                    .foregroundStyle(DashboardTheme.textSecondary)

                VStack(alignment: .leading, spacing: 16) {
                    settingsToggleSection
                    settingsSliderSection
                }
                .padding(16)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .padding(.vertical, 4)
        }
    }

    private var settingsToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Editor Display")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.7))
            Toggle("Tampilkan nomor baris", isOn: $preferences.showLineNumbers)
                .toggleStyle(.switch)
            Toggle("Tampilkan status bar", isOn: $preferences.showStatusBar)
                .toggleStyle(.switch)
        }
    }

    private var settingsSliderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Typography")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.7))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Ukuran font")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(DashboardTheme.textPrimary)
                    Spacer()
                    Text("\(Int(preferences.fontSize)) pt")
                        .font(.footnote)
                        .foregroundStyle(DashboardTheme.textSecondary)
                }
                Slider(
                    value: Binding(
                        get: { preferences.fontSize },
                        set: { preferences.fontSize = $0 }
                    ),
                    in: 10...24,
                    step: 1
                )
            }
        }
    }

    private func iconWidgetButton(
        icon: String,
        tint: Color,
        label: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .frame(width: 54, height: 54)
                .foregroundStyle(disabled ? DashboardTheme.textSecondary.opacity(0.6) : tint)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(disabled ? 0.08 : 0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(disabled ? 0.2 : 0.45), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .frame(width: 58, height: 58)
        .opacity(disabled ? 0.55 : 1)
        .disabled(disabled)
        .accessibilityLabel(label)
        .accessibilityHint(label)
    }

    private func iconStatusTile(icon: String, tint: Color, label: String, showsStatus: Bool = true) -> some View {
        Image(systemName: icon)
            .font(.title2.weight(.semibold))
            .frame(width: 54, height: 54)
            .foregroundStyle(tint)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(0.42), lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                if showsStatus {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(2)
                        .background(Circle().fill(tint))
                        .offset(x: 4, y: 4)
                }
            }
            .frame(width: 58, height: 58)
            .accessibilityLabel(label)
            .accessibilityHint(label)
    }

    private func startRename(_ file: CodeFile) {
        onSelectFile(file)
        renameDraft = file.name
        renameError = nil
        renamingFileID = file.id
        DispatchQueue.main.async { renameFieldFocused = true }
    }

    private func cancelRename() {
        renamingFileID = nil
        renameDraft = ""
        renameError = nil
        renameFieldFocused = false
    }

    private func commitRename(for file: CodeFile) {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            renameError = "Nama file tidak boleh kosong."
            return
        }
        onRenameFile(file, trimmed)
        cancelRename()
    }

    private func handleDelete(_ file: CodeFile) {
        pendingDelete = file
    }

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if folders.isEmpty == false {
                Text("Folder")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DashboardTheme.textSecondary)
                    .padding(.horizontal, 4)
            }
            ForEach(folders) { folder in
                folderGroup(for: folder)
            }
        }
    }

    private func folderGroup(for folder: CodeFolder) -> some View {
        let isExpanded = expandedFolders.contains(folder.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    if isExpanded {
                        expandedFolders.remove(folder.id)
                    } else {
                        expandedFolders.insert(folder.id)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isExpanded ? "folder.fill" : "folder")
                            .foregroundStyle(Color.accentBlue)
                            .font(.headline)
                        Text(folder.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DashboardTheme.textPrimary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    onCreateFile(folder)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    if isExpanded {
                        expandedFolders.remove(folder.id)
                    } else {
                        expandedFolders.insert(folder.id)
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DashboardTheme.textSecondary)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )

            if isExpanded {
                VStack(spacing: 8) {
                    let files = filesProvider(folder)
                    if files.isEmpty {
                        Text("Belum ada file di folder ini.")
                            .font(.caption)
                            .foregroundStyle(DashboardTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(files) { file in
                            fileRow(for: file)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var looseFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if looseFiles.isEmpty == false {
                Text("File Bebas")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DashboardTheme.textSecondary)
                    .padding(.horizontal, 4)
                VStack(spacing: 10) {
                    ForEach(looseFiles) { file in
                        fileRow(for: file)
                    }
                }
            }
        }
    }

    private func fileRow(for file: CodeFile) -> some View {
        let isSelected = file.id == selectedID
        return Group {
            if renamingFileID == file.id {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Nama file baru", text: $renameDraft, prompt: Text("Contoh: index.html"))
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .focused($renameFieldFocused)
                        .onSubmit { commitRename(for: file) }

                    if let renameError {
                        Text(renameError)
                            .font(.caption2)
                            .foregroundStyle(Color.red)
                    }

                    HStack(spacing: 12) {
                        Button("Simpan") { commitRename(for: file) }
                            .buttonStyle(.borderedProminent)
                            .tint(file.language.accentColor)
                        Button("Batal", role: .cancel) { cancelRename() }
                            .buttonStyle(.bordered)
                    }
                    .font(.caption.bold())
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(file.language.accentColor.opacity(0.12))
                )
                .onAppear {
                    DispatchQueue.main.async {
                        renameFieldFocused = true
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: fileIconName(for: file))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(file.language.accentColor)
                        .frame(width: 26, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isSelected ? DashboardTheme.textPrimary : DashboardTheme.textPrimary.opacity(0.9))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 16)

                    Button {
                        startRename(file)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DashboardTheme.textPrimary)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ganti nama \(file.name)")

                    Button(role: .destructive) {
                        handleDelete(file)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.red.opacity(0.9))
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hapus \(file.name)")
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? file.language.accentColor.opacity(0.12) : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onTapGesture {
                    onSelectFile(file)
                }
                .contextMenu {
                    Button("Buka") { onSelectFile(file) }
                    Button("Preview") {
                        onSelectFile(file)
                        onOpenPreview()
                    }
                    .disabled(inlinePreviewAvailable)
                    Button("Ganti Nama") {
                        startRename(file)
                    }
                    Button("Duplikat") {
                        onDuplicateFile(file)
                    }
                    Button("Hapus", role: .destructive) {
                        handleDelete(file)
                    }
                }
            }
        }
    }

    private func fileIconName(for file: CodeFile) -> String {
        let icon = file.language.iconName.trimmingCharacters(in: .whitespacesAndNewlines)
        return icon.isEmpty ? "chevron.left.slash.chevron.right" : icon
    }
}

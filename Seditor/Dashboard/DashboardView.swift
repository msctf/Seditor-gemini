import SwiftUI

struct DashboardView: View {
    @ObservedObject var model: DashboardViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let safeTop = proxy.safeAreaInsets.top
                let toolbarTopPadding = layoutTopPadding
                let panelTopInset = max(safeTop + toolbarTopPadding - 8, safeTop)
                let usableWidth = max(proxy.size.width - layoutHorizontalPadding * 2, 0)
                let pinnedSidebar = shouldUsePinnedSidebar(usableWidth: usableWidth)
                let contentWidth = resolvedContentMaxWidth(
                    usableWidth: usableWidth,
                    pinnedSidebar: pinnedSidebar
                )
                let layoutMetrics = workspaceMetrics(
                    usableWidth: usableWidth,
                    contentMaxWidth: contentWidth,
                    pinnedSidebar: pinnedSidebar,
                    canPreview: model.canPreview
                )

                ZStack(alignment: .topLeading) {
                    DashboardTheme.backgroundGradient
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        topToolbar(
                            pinnedSidebar: pinnedSidebar,
                            inlinePreview: layoutMetrics.previewWidth != nil
                        )
                            .padding(.horizontal, toolbarHorizontalPadding)
                            .frame(maxWidth: contentWidth ?? .infinity, alignment: .leading)

                        Divider()
                            .overlay(Color.white.opacity(0.05))
                            .frame(maxWidth: contentWidth ?? .infinity)

                        workspaceContent(
                            maxWidth: contentWidth,
                            metrics: layoutMetrics
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, layoutHorizontalPadding)
                    .padding(.top, toolbarTopPadding)
                    .padding(.bottom, layoutBottomPadding)

                    if !pinnedSidebar && model.isMenuVisible {
                        Color.black.opacity(0.45)
                            .ignoresSafeArea()
                            .onTapGesture { model.toggleMenu(show: false) }

                        HStack(spacing: 0) {
                            FilesSidebarView(
                                folders: model.folderOptions,
                                looseFiles: model.looseFiles,
                                filesProvider: { model.files(in: $0) },
                                selectedID: model.selectedFile?.id,
                                currentProjectName: model.currentProject?.name,
                                activeFile: model.selectedFile,
                                inlinePreviewAvailable: false,
                                onSelectFile: model.selectFile,
                                onCreateFile: { folder in
                                    model.openNewFile(in: folder)
                                },
                                onCreateFolder: {
                                    model.toggleMenu(show: false)
                                    model.toggleFolderSheet(show: true)
                                },
                                onImport: {
                                    model.toggleMenu(show: false)
                                    model.toggleImporter(show: true)
                                },
                                onLoadTemplate: {
                                    model.loadStarterTemplate()
                                },
                                onManageProjects: {
                                    model.toggleMenu(show: false)
                                    model.isShowingProjectManager = true
                                },
                                onOpenAI: {
                                    model.toggleMenu(show: false)
                                    model.isShowingAI = true
                                },
                                onOpenPreview: {
                                    model.toggleMenu(show: false)
                                    model.togglePreview(show: true)
                                },
                                onRenameFile: { file, newName in
                                    model.toggleMenu(show: false)
                                    model.renameFile(file, to: newName)
                                },
                                onDuplicateFile: { file in
                                    model.toggleMenu(show: false)
                                    model.duplicateFile(file)
                                },
                                onDeleteFile: { file in
                                    model.toggleMenu(show: false)
                                    model.deleteFile(file)
                                },
                                onClose: {
                                    model.toggleMenu(show: false)
                                },
                                preferences: $model.editorPreferences
                            )
                            .padding(.top, panelTopInset)
                            .padding(.leading, layoutHorizontalPadding)
                            Spacer()
                                .contentShape(Rectangle())
                                .onTapGesture { model.toggleMenu(show: false) }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .navigationBarHidden(true)
                .onChange(of: isRegularLayout) { isRegular in
                    if isRegular {
                        model.toggleMenu(show: false)
                    }
                }
                .onAppear {
                    if isRegularLayout {
                        model.toggleMenu(show: false)
                    }
                }
                .onChange(of: pinnedSidebar) { isPinned in
                    if isPinned && model.isShowingPreview {
                        model.togglePreview(show: false)
                    }
                }
            }
        }
        .sheet(isPresented: $model.isShowingNewFileSheet) {
            NewFileSheet(
                folders: model.folderOptions,
                initialFolder: model.pendingFolderForNewFile,
                onCreate: { file, folder in
                    model.appendFile(file, to: folder)
                    model.toggleNewFileSheet(show: false)
                },
                onDismiss: {
                    model.toggleNewFileSheet(show: false)
                }
            )
        }
        .sheet(isPresented: $model.isShowingFolderSheet) {
            NewFolderSheet(
                onCreate: { name in
                    model.createFolder(named: name)
                    model.toggleFolderSheet(show: false)
                },
                onDismiss: {
                    model.toggleFolderSheet(show: false)
                }
            )
        }
        .sheet(isPresented: $model.isShowingAI) {
            AIAgentSheet(
                settings: $model.aiSettings,
                activeFile: model.selectedFile,
                onUpdateSettings: model.saveAISettings,
                onApplyChange: model.applyGeneratedChange
            )
        }
        .sheet(isPresented: $model.isShowingProjectManager) {
            ProjectManagerView(model: model)
        }
        .fileImporter(
            isPresented: $model.isShowingImporter,
            allowedContentTypes: CodeLanguage.supportedContentTypes,
            allowsMultipleSelection: false,
            onCompletion: model.handleImport
        )
        .alert("Notice", isPresented: .init(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } })
        ) {
            Button("OK", role: .cancel) { model.alertMessage = nil }
        } message: {
            Text(model.alertMessage ?? "")
        }
    }

    private func workspaceContent(
        maxWidth: CGFloat?,
        metrics: WorkspaceMetrics
    ) -> some View {
        HStack(spacing: metrics.spacing) {
            if metrics.pinnedSidebar {
                FilesSidebarView(
                    folders: model.folderOptions,
                    looseFiles: model.looseFiles,
                    filesProvider: { model.files(in: $0) },
                    selectedID: model.selectedFile?.id,
                    currentProjectName: model.currentProject?.name,
                    activeFile: model.selectedFile,
                    inlinePreviewAvailable: metrics.previewWidth != nil,
                    onSelectFile: model.selectFile,
                    onCreateFile: { folder in
                        model.openNewFile(in: folder)
                    },
                    onCreateFolder: {
                        model.toggleFolderSheet(show: true)
                    },
                    onImport: {
                        model.toggleImporter(show: true)
                    },
                    onLoadTemplate: {
                        model.loadStarterTemplate()
                    },
                    onManageProjects: {
                        model.isShowingProjectManager = true
                    },
                    onOpenAI: { model.isShowingAI = true },
                    onOpenPreview: { model.togglePreview(show: true) },
                    onRenameFile: { file, newName in model.renameFile(file, to: newName) },
                    onDuplicateFile: { model.duplicateFile($0) },
                    onDeleteFile: { model.deleteFile($0) },
                    onClose: {},
                    showsCloseButton: false,
                    preferences: $model.editorPreferences
                )
                .frame(width: metrics.sidebarWidth)
                .padding(.vertical, 12)
            }

            Group {
                editorStage
                    .clipShape(metrics.pinnedSidebar ? RoundedRectangle(cornerRadius: 26, style: .continuous) : RoundedRectangle(cornerRadius: 0))
                    .overlay(
                        Group {
                            if metrics.pinnedSidebar {
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            }
                        }
                    )
                    .shadow(color: metrics.pinnedSidebar ? Color.black.opacity(0.18) : .clear, radius: 24, y: 18)
            }
            .frame(maxWidth: metrics.editorMaxWidth ?? .infinity, maxHeight: .infinity)

            if let previewWidth = metrics.previewWidth {
                Divider()
                    .frame(height: nil)
                    .overlay(Color.white.opacity(0.06))
                    .padding(.vertical, 12)

                PreviewCanvas(html: model.combinedHTML)
                    .frame(width: previewWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 24, y: 18)
            }
        }
        .padding(.top, metrics.pinnedSidebar ? 12 : 0)
        .frame(maxWidth: maxWidth ?? .infinity, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func topToolbar(pinnedSidebar: Bool, inlinePreview: Bool) -> some View {
        HStack(spacing: 16) {
            if !pinnedSidebar {
                Button {
                    model.toggleMenu()
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(model.isMenuVisible ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            } else {
                Label(model.currentProject?.name ?? "Workspace", systemImage: "square.grid.2x2")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }

            Text(model.selectedFile?.name ?? "No file selected")
                .font(.headline.monospaced())
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)

            Spacer()

            Button {
                model.isShowingAI = true
            } label: {
                Image(systemName: "brain.head.profile")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)

            if !inlinePreview {
                Button {
                    model.togglePreview(show: !model.isShowingPreview)
                } label: {
                    Image(systemName: model.isShowingPreview ? "chevron.left.circle.fill" : "play.circle.fill")
                        .font(.title3.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .foregroundStyle(
                            model.isShowingPreview || model.canPreview
                            ? Color.black
                            : DashboardTheme.textSecondary
                        )
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: (model.isShowingPreview || model.canPreview)
                                        ? [Color.accentOrange, Color.accentOrange.opacity(0.72)]
                                        : [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .accessibilityLabel(model.isShowingPreview ? "Back to editor" : "Preview")
                .disabled(!model.isShowingPreview && !model.canPreview)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, isRegularLayout ? 0 : 8)
        .padding(.bottom, 12)
    }

    private var editorStage: some View {
        ZStack {
            let background = Color(red: 0.05, green: 0.06, blue: 0.08)
            if isRegularLayout {
                background
            } else {
                background.ignoresSafeArea()
            }

            if model.isShowingPreview {
                PreviewCanvas(html: model.combinedHTML)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if let binding = model.selectedFileBinding {
                EditorWorkspaceView(file: binding, onReset: {
                    if let file = model.selectedFile {
                        model.resetContents(of: file)
                    }
                }, preferences: model.editorPreferences)
                .transition(.opacity.combined(with: .scale))
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: model.isShowingPreview)
        .animation(.easeInOut(duration: 0.2), value: model.selectedFileID)
    }

    private var placeholder: some View {
        VStack(spacing: 18) {
            Image(systemName: "rectangle.and.pencil.and.ellipsis")
                .font(.system(size: 54))
                .foregroundStyle(Color.accentBlue)
            Text("No file selected")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DashboardTheme.textPrimary)
            Text("Open the menu to create or import a file. The editor will appear here with syntax highlighting and line numbers.")
                .font(.subheadline)
                .foregroundStyle(DashboardTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isRegularLayout: Bool {
        if let horizontal = horizontalSizeClass {
            return horizontal == .regular
        }
        if let vertical = verticalSizeClass {
            return vertical != .compact
        }
        return true
    }

    private var layoutHorizontalPadding: CGFloat {
        isRegularLayout ? 28 : 12
    }

    private var toolbarHorizontalPadding: CGFloat {
        isRegularLayout ? 0 : 8
    }

    private var layoutTopPadding: CGFloat {
        isRegularLayout ? 22 : 16
    }

    private var layoutBottomPadding: CGFloat {
        isRegularLayout ? 28 : 16
    }

    private func shouldUsePinnedSidebar(usableWidth: CGFloat) -> Bool {
        isRegularLayout && usableWidth >= 760
    }

    private struct WorkspaceMetrics {
        let pinnedSidebar: Bool
        let spacing: CGFloat
        let sidebarWidth: CGFloat
        let previewWidth: CGFloat?
        let editorMaxWidth: CGFloat?
    }

    private func workspaceMetrics(
        usableWidth: CGFloat,
        contentMaxWidth: CGFloat?,
        pinnedSidebar: Bool,
        canPreview: Bool
    ) -> WorkspaceMetrics {
        let spacing = resolvedWorkspaceSpacing(usableWidth: usableWidth, pinnedSidebar: pinnedSidebar)
        let sidebarWidth = pinnedSidebar ? resolvedSidebarWidth(usableWidth: usableWidth) : 0
        var previewWidth: CGFloat? = nil
        var editorMaxWidth: CGFloat? = nil

        let containerWidth = max(contentMaxWidth ?? usableWidth, 0)

        if pinnedSidebar {
            var remaining = max(containerWidth - sidebarWidth, 0)
            remaining = max(remaining - spacing, 0)

            editorMaxWidth = remaining

            if canPreview {
                let previewCandidateWidth = max(remaining - spacing, 0)
                if let candidate = resolvedPreviewWidth(availableContentWidth: previewCandidateWidth) {
                    previewWidth = candidate
                    remaining = max(remaining - spacing - candidate, 0)
                    editorMaxWidth = remaining
                }
            }
        }

        return WorkspaceMetrics(
            pinnedSidebar: pinnedSidebar,
            spacing: spacing,
            sidebarWidth: sidebarWidth,
            previewWidth: previewWidth,
            editorMaxWidth: editorMaxWidth
        )
    }

    private func resolvedWorkspaceSpacing(usableWidth: CGFloat, pinnedSidebar: Bool) -> CGFloat {
        guard pinnedSidebar else { return 0 }
        return usableWidth >= 1200 ? 32 : 20
    }

    private func resolvedSidebarWidth(usableWidth: CGFloat) -> CGFloat {
        let minWidth: CGFloat = 280
        let maxWidth: CGFloat = 360
        let proportional = usableWidth * 0.24
        return min(max(proportional, minWidth), maxWidth)
    }

    private func resolvedPreviewWidth(availableContentWidth: CGFloat) -> CGFloat? {
        let minPreviewWidth: CGFloat = 320
        let minEditorWidth: CGFloat = 520
        guard availableContentWidth > (minPreviewWidth + minEditorWidth) else { return nil }

        let preferred = availableContentWidth * 0.38
        let maxPreviewWidth = availableContentWidth - minEditorWidth
        let clamped = min(max(preferred, minPreviewWidth), maxPreviewWidth)
        return clamped
    }

    private func resolvedContentMaxWidth(
        usableWidth: CGFloat,
        pinnedSidebar: Bool
    ) -> CGFloat? {
        pinnedSidebar ? usableWidth : nil
    }

private struct PreviewCanvas: View {
    let html: String

    var body: some View {
        WebPreviewView(content: html)
            .background(Color(red: 0.06, green: 0.07, blue: 0.11))
    }
}
}

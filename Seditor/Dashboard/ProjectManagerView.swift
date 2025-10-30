import SwiftUI

struct ProjectManagerView: View {
    @ObservedObject var model: DashboardViewModel
    @State private var newProjectName: String = ""
    @State private var includeStarterTemplate = false
    @State private var renameText: String = ""
    @FocusState private var isRenameFocused: Bool
    @FocusState private var isNewProjectFocused: Bool

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List {
                currentProjectSection
                savedProjectsSection
                newProjectSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Manajer Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") {
                        model.isShowingProjectManager = false
                    }
                }
            }
            .onAppear {
                renameText = model.currentProject?.name ?? ""
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var currentProjectSection: some View {
        Section("Project Aktif") {
            if let current = model.currentProject {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Nama project", text: $renameText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isRenameFocused)
                        .submitLabel(.done)
                        .onSubmit { commitRename() }

                    HStack {
                        Spacer()
                        Button {
                            commitRename()
                        } label: {
                            Label("Simpan Nama", systemImage: "checkmark")
                                .font(.subheadline.weight(.semibold))
                        }
                        .disabled(renameText.trimmed().isEmpty || renameText.trimmed() == current.name)
                        Spacer()
                    }
                    .padding(.top, 2)

                    Text("Terakhir diperbarui \(relativeDateString(for: current.updatedAt)) lalu")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Belum ada project aktif. Project akan dibuat saat kamu menyimpan perubahan.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var savedProjectsSection: some View {
        Section("Project Tersimpan") {
            if model.projects.isEmpty {
                Text("Belum ada project lain. Buat project baru untuk menyimpan workspace terpisah.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.projects) { project in
                    Button {
                        model.selectProject(project)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name)
                                    .fontWeight(project.id == model.currentProject?.id ? .semibold : .regular)
                                    .foregroundStyle(project.id == model.currentProject?.id ? Color.accentColor : Color.primary)
                                Text("Diupdate \(relativeDateString(for: project.updatedAt)) lalu")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if project.id == model.currentProject?.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if project.id != model.currentProject?.id {
                            Button(role: .destructive) {
                                model.deleteProject(project)
                            } label: {
                                Label("Hapus", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var newProjectSection: some View {
        Section("Project Baru") {
            TextField("Nama project baru", text: $newProjectName)
                .textFieldStyle(.roundedBorder)
                .focused($isNewProjectFocused)
                .submitLabel(.done)
                .onSubmit { commitNewProject() }

            Toggle(isOn: $includeStarterTemplate) {
                Text("Isi dengan template starter")
            }

            Button {
                commitNewProject()
            } label: {
                Label("Buat Project", systemImage: "folder.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .disabled(newProjectName.trimmed().isEmpty)
        }
    }

    private func commitRename() {
        let trimmed = renameText.trimmed()
        guard let current = model.currentProject,
              !trimmed.isEmpty,
              trimmed != current.name else { return }
        model.renameCurrentProject(to: trimmed)
        renameText = trimmed
    }

    private func commitNewProject() {
        let trimmed = newProjectName.trimmed()
        guard !trimmed.isEmpty else { return }
        model.createProject(named: trimmed, includeStarter: includeStarterTemplate)
        newProjectName = ""
        includeStarterTemplate = false
        isNewProjectFocused = false
    }

    private func relativeDateString(for date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

private extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

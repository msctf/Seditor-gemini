import SwiftUI

struct NewFileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var language: CodeLanguage = .html
    @State private var selectedFolderID: UUID?

    let folders: [CodeFolder]
    let initialFolder: CodeFolder?
    let onCreate: (CodeFile, CodeFolder?) -> Void
    let onDismiss: () -> Void

    init(
        folders: [CodeFolder],
        initialFolder: CodeFolder?,
        onCreate: @escaping (CodeFile, CodeFolder?) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.folders = folders
        self.initialFolder = initialFolder
        self.onCreate = onCreate
        self.onDismiss = onDismiss
        _selectedFolderID = State(initialValue: initialFolder?.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("File name", text: $name)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    Picker("Language", selection: $language) {
                        ForEach(CodeLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                }
                if folders.isEmpty == false {
                    Section("Location") {
                        Picker("Folder", selection: $selectedFolderID) {
                            Text("None").tag(Optional<UUID>.none)
                            ForEach(folders) { folder in
                                Text(folder.name).tag(Optional(folder.id))
                            }
                        }
                    }
                }

                Section("Template Summary") {
                    Text(language.templatePreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle("New File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createAndDismiss()
                    }
                }
            }
        }
    }

    private func createAndDismiss() {
        var trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            trimmed = language.placeholder
        }
        if !trimmed.lowercased().hasSuffix(".\(language.fileExtension)") {
            trimmed += ".\(language.fileExtension)"
        }
        let file = CodeFile(name: trimmed, language: language, content: language.template)
        let folder = folders.first(where: { $0.id == selectedFolderID })
        onCreate(file, folder)
        dismiss()
    }
}

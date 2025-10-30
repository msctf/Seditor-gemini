import SwiftUI

struct AISettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var settings: AISettings
    @State private var workingSettings: AISettings
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false
    @State private var modelsError: String?
    let onSave: (AISettings) -> Void
    let onNewChat: () -> Void

    init(settings: Binding<AISettings>, onSave: @escaping (AISettings) -> Void, onNewChat: @escaping () -> Void = {}) {
        _settings = settings
        _workingSettings = State(initialValue: settings.wrappedValue)
        self.onSave = onSave
        self.onNewChat = onNewChat
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("API Key") {
                    SecureField("Masukkan API key Gemini kamu", text: $workingSettings.apiKey)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                }

                Section("Model") {
                    if workingSettings.apiKey.isEmpty {
                        Text("Masukkan API key terlebih dahulu untuk memuat daftar model Gemini.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if isLoadingModels {
                        HStack {
                            ProgressView()
                            Text("Mengambil daftar model...")
                                .foregroundStyle(.secondary)
                        }
                    } else if availableModels.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            if let modelsError {
                                Text(modelsError)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                            Button("Muat daftar model") {
                                Task { await fetchModels() }
                            }
                        }
                    } else {
                        Picker("Model", selection: $workingSettings.model) {
                            ForEach(availableModels, id: \.self) { model in
                                Text(model)
                                    .font(.system(.body, design: .monospaced))
                                    .tag(model)
                            }
                        }
                    }
                }

                Section("Respons") {
                    VStack(alignment: .leading) {
                        Slider(value: $workingSettings.temperature, in: 0...1, step: 0.05)
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(workingSettings.temperature.formatted(.number.precision(.fractionLength(2))))
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading) {
                        Slider(value: $workingSettings.topP, in: 0.1...1, step: 0.05)
                        HStack {
                            Text("Top P")
                            Spacer()
                            Text(workingSettings.topP.formatted(.number.precision(.fractionLength(2))))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Catatan") {
                    Text("API key disimpan lokal di Keychain. Pastikan sudah mengaktifkan API Gemini di Google AI Studio dan menyalin key yang benar.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Percakapan") {
                    Button {
                        onNewChat()
                        dismiss()
                    } label: {
                        Label("Mulai Chat Baru", systemImage: "bubble.left.and.bubble.right")
                    }
                }
            }
            .navigationTitle("Pengaturan AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        settings = workingSettings
                        onSave(workingSettings)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await fetchModels()
        }
        .onChange(of: workingSettings.apiKey) { _ in
            availableModels = []
            modelsError = nil
            Task { await fetchModels() }
        }
    }

    private func fetchModels() async {
        guard workingSettings.apiKey.isEmpty == false else { return }
        guard availableModels.isEmpty else { return }
        await MainActor.run {
            isLoadingModels = true
            modelsError = nil
        }
        do {
            let models = try await GeminiClient().fetchModels(apiKey: workingSettings.apiKey)
            await MainActor.run {
                self.availableModels = models
                if models.contains(workingSettings.model) == false, let first = models.first {
                    workingSettings.model = first
                }
            }
        } catch {
            await MainActor.run {
                availableModels = []
                modelsError = error.localizedDescription
            }
        }
        await MainActor.run {
            isLoadingModels = false
        }
    }
}

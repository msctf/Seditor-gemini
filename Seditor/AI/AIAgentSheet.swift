import SwiftUI

struct AIAgentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Binding var settings: AISettings
    let activeFile: CodeFile?
    let onUpdateSettings: (AISettings) -> Void
    let onApplyChange: (PendingChange) -> Void

    private static let introMessage = "Hai! Aku siap bantu kamu ngoding. Tulis instruksi atau pertanyaanmu di bawah ya."

    private let conversationStore = AIConversationStore.shared

    @State private var prompt: String = ""
    @State private var conversation: [Message] = [
        Message(role: .assistant, content: .text(Self.introMessage))
    ]
    @State private var isThinking = false
    @State private var showSettings = false
    @State private var errorMessage: String?
    @State private var pendingChange: PendingChange?
    @State private var activeAnalysisMessageID: UUID?
    @State private var isRestoringConversation = false

    private let client = GeminiClient()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                conversationView

                Divider()

                VStack(spacing: 8) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    HStack(spacing: 12) {
                        TextField("Tulis perintah untuk kode yang sedang kamu buka...", text: $prompt, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...4)
                            .disabled(isThinking || activeFile == nil)

                        Button {
                            Task { await sendPrompt() }
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(promptReady ? Color.accentColor : .gray)
                        }
                        .disabled(!promptReady || isThinking)
                    }
                }
                .padding(.horizontal, inputHorizontalPadding)
                .padding(.vertical, 16)
                .frame(maxWidth: conversationMaxWidth)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("AI Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button {
                            startNewChat()
                        } label: {
                            Label("New Chat", systemImage: "bubble.left")
                                .labelStyle(.iconOnly)
                                .imageScale(.large)
                        }
                        .buttonStyle(.plain)

                        Button {
                            showSettings = true
                        } label: {
                            Label("Pengaturan", systemImage: "slider.horizontal.3")
                                .labelStyle(.iconOnly)
                                .imageScale(.large)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: containerMaxWidth ?? .infinity)
            .padding(.horizontal, outerHorizontalPadding)
            .padding(.vertical, outerVerticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .sheet(isPresented: $showSettings) {
            AISettingsSheet(settings: $settings, onSave: { newSettings in
                onUpdateSettings(newSettings)
                showSettings = false
            }, onNewChat: {
                startNewChat()
            })
        }
        .preferredColorScheme(.dark)
        .onAppear {
            restoreConversationForCurrentFile()
        }
        .onChange(of: activeFile?.id) { _ in
            restoreConversationForCurrentFile()
        }
        .onChange(of: conversation) { _ in
            persistConversationState()
        }
        .onChange(of: pendingChange) { _ in
            persistConversationState()
        }
    }

    private func userBubble(_ text: String) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(text)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.accentBlue.opacity(0.35))
                )
                .foregroundStyle(.white)
                .frame(maxWidth: bubbleMaxWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func startNewChat() {
        conversation = defaultConversation
        prompt = ""
        errorMessage = nil
        pendingChange = nil
        activeAnalysisMessageID = nil
        persistConversationState()
    }

    @ViewBuilder
    private func assistantBubble(for message: Message) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Seditor AI", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))

            switch message.content {
            case .text(let text):
                Text(text)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .foregroundStyle(.white)
                    .frame(maxWidth: bubbleMaxWidth, alignment: .leading)
            case .analysisStatus(let status):
                AnalysisStatusView(startedAt: status.startedAt, currentStep: status.currentStep)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            case .steps(let summary):
                StepSummaryBubble(summary: summary)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            case .code(let codeContent):
                CodeChangeBubble(
                    content: codeContent,
                    onApply: {
                        applyPendingChange(for: message.id)
                    }
                )
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    )
            }
        }
        .frame(maxWidth: bubbleMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var promptReady: Bool {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        settings.apiKey.isEmpty == false &&
        activeFile != nil
    }

    private var isRegularWidth: Bool {
        if let horizontal = horizontalSizeClass {
            return horizontal == .regular
        }
        if let vertical = verticalSizeClass {
            return vertical != .compact
        }
        return true
    }

    private var containerMaxWidth: CGFloat? {
        isRegularWidth ? 760 : nil
    }

    private var bubbleMaxWidth: CGFloat {
        isRegularWidth ? 640 : 360
    }

    private var conversationHorizontalPadding: CGFloat {
        isRegularWidth ? 32 : 20
    }

    private var conversationMaxWidth: CGFloat? {
        isRegularWidth ? 720 : nil
    }

    private var outerHorizontalPadding: CGFloat {
        isRegularWidth ? 24 : 0
    }

    private var outerVerticalPadding: CGFloat {
        isRegularWidth ? 24 : 0
    }

    private var inputHorizontalPadding: CGFloat {
        isRegularWidth ? 32 : 16
    }

    @ViewBuilder
    private var conversationView: some View {
        if let file = activeFile {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        fileContextCard(for: file)
                        ForEach(conversation) { message in
                            bubble(for: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, conversationHorizontalPadding)
                    .padding(.vertical, 20)
                    .frame(maxWidth: conversationMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.black.opacity(0.15))
                .onChange(of: conversation.count) { _ in
                    guard let last = conversation.last else { return }
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            VStack(spacing: 16) {
                Image(systemName: "doc.text.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Belum ada file yang aktif")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Buka file di editor terlebih dahulu supaya AI bisa membaca konteks kode yang ingin kamu ubah.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .padding(.horizontal, conversationHorizontalPadding)
            .padding(.vertical, 24)
            .frame(maxWidth: conversationMaxWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.15))
        }
    }

    @ViewBuilder
    private func bubble(for message: Message) -> some View {
        switch message.role {
        case .user:
            if case .text(let text) = message.content {
                userBubble(text)
            }
        case .assistant:
            assistantBubble(for: message)
        }
    }

    @MainActor
    private func sendPrompt() async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        guard settings.apiKey.isEmpty == false else {
            errorMessage = "Masukkan API key Gemini terlebih dahulu di pengaturan."
            return
        }
        guard let file = activeFile else {
            errorMessage = "Tidak ada file aktif. Buka file terlebih dahulu."
            return
        }

        errorMessage = nil
        pendingChange = nil
        let userMessage = Message(role: .user, content: .text(trimmed))
        conversation.append(userMessage)
        prompt = ""
        isThinking = true

        let statusContent = AnalysisStatusContent(startedAt: Date(), currentStep: "Menyiapkan analisis awal...")
        let statusMessage = Message(role: .assistant, content: .analysisStatus(statusContent))
        activeAnalysisMessageID = statusMessage.id
        conversation.append(statusMessage)

        do {
            let analysisMessageID = statusMessage.id
            let result = try await runAgent(prompt: trimmed, file: file) { step in
                await updateAnalysisStatus(messageID: analysisMessageID, step: step)
            }
            let duration = Date().timeIntervalSince(statusContent.startedAt)
            pendingChange = (result.change.edits.isEmpty && result.change.fullContent == nil) ? nil : result.change

            if let messageID = activeAnalysisMessageID,
               let index = conversation.firstIndex(where: { $0.id == messageID }) {
                conversation[index].content = .steps(
                    StepSummaryContent(
                        steps: result.steps,
                        summaryText: result.summary,
                        notes: result.notes,
                        duration: duration,
                        codeApplied: false
                    )
                )
            }
            if result.change.edits.isEmpty && result.change.fullContent == nil {
                errorMessage = "AI tidak menghasilkan patch otomatis. Tinjau catatan analisis untuk perubahan manual."
            } else {
                let explanationText = result.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
                let codeContent = CodeSummaryContent(
                    change: result.change,
                    applied: false,
                    codeBlock: result.codeBlock,
                    explanation: explanationText.isEmpty ? nil : explanationText
                )
                conversation.append(
                    Message(
                        role: .assistant,
                        content: .code(codeContent)
                    )
                )
                errorMessage = nil
            }
        } catch {
            let failureText = "Gagal memanggil Gemini: \(error.localizedDescription)"
            if let messageID = activeAnalysisMessageID,
               let index = conversation.firstIndex(where: { $0.id == messageID }) {
                conversation[index].content = .text(failureText)
            } else {
                conversation.append(Message(role: .assistant, content: .text(failureText)))
            }
            errorMessage = failureText
        }
        activeAnalysisMessageID = nil
        isThinking = false
        persistConversationState()
    }

    private struct Message: Identifiable, Codable, Equatable {
        enum Role: String, Codable {
            case assistant
            case user

            var geminiRole: String {
                switch self {
                case .assistant: return "model"
                case .user: return "user"
                }
            }
        }

        enum Content: Equatable {
            case text(String)
            case analysisStatus(AnalysisStatusContent)
            case steps(StepSummaryContent)
            case code(CodeSummaryContent)
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case role
            case content
        }

        private enum ContentCodingKeys: String, CodingKey {
            case type
            case text
            case status
            case summary
            case code
        }

        let id: UUID
        let role: Role
        var content: Content

        init(id: UUID = UUID(), role: Role, content: Content) {
            self.id = id
            self.role = role
            self.content = content
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            role = try container.decode(Role.self, forKey: .role)
            let contentContainer = try container.nestedContainer(keyedBy: ContentCodingKeys.self, forKey: .content)
            let type = try contentContainer.decode(String.self, forKey: .type)
            switch type {
            case "text":
                let value = try contentContainer.decode(String.self, forKey: .text)
                content = .text(value)
            case "analysisStatus":
                let status = try contentContainer.decode(AnalysisStatusContent.self, forKey: .status)
                content = .analysisStatus(status)
            case "steps":
                let summary = try contentContainer.decode(StepSummaryContent.self, forKey: .summary)
                content = .steps(summary)
            case "code":
                let code = try contentContainer.decode(CodeSummaryContent.self, forKey: .code)
                content = .code(code)
            default:
                content = .text("")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(role, forKey: .role)
            var contentContainer = container.nestedContainer(keyedBy: ContentCodingKeys.self, forKey: .content)
            switch content {
            case .text(let value):
                try contentContainer.encode("text", forKey: .type)
                try contentContainer.encode(value, forKey: .text)
            case .analysisStatus(let status):
                try contentContainer.encode("analysisStatus", forKey: .type)
                try contentContainer.encode(status, forKey: .status)
            case .steps(let summary):
                try contentContainer.encode("steps", forKey: .type)
                try contentContainer.encode(summary, forKey: .summary)
            case .code(let code):
                try contentContainer.encode("code", forKey: .type)
                try contentContainer.encode(code, forKey: .code)
            }
        }

        static func == (lhs: Message, rhs: Message) -> Bool {
            lhs.id == rhs.id && lhs.role == rhs.role && lhs.content == rhs.content
        }

        var geminiMessage: GeminiMessage? {
            switch content {
            case .text(let text):
                return GeminiMessage(role: role.geminiRole, parts: [GeminiMessage.Part(text: text)])
            case .analysisStatus, .steps, .code:
                return nil
            }
        }
    }

    private struct AnalysisStatusContent: Codable, Equatable {
        let startedAt: Date
        var currentStep: String
    }

    private struct StepSummaryContent: Codable, Equatable {
        var steps: [AgentStep]
        var summaryText: String
        var notes: [String]
        var duration: TimeInterval
        var codeApplied: Bool

        private enum CodingKeys: String, CodingKey {
            case steps
            case summaryText
            case notes
            case duration
            case codeApplied
        }

        init(steps: [AgentStep], summaryText: String, notes: [String], duration: TimeInterval, codeApplied: Bool) {
            self.steps = steps
            self.summaryText = summaryText
            self.notes = notes
            self.duration = duration
            self.codeApplied = codeApplied
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            steps = try container.decode([AgentStep].self, forKey: .steps)
            summaryText = try container.decode(String.self, forKey: .summaryText)
            notes = try container.decodeIfPresent([String].self, forKey: .notes) ?? []
            duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
            codeApplied = try container.decodeIfPresent(Bool.self, forKey: .codeApplied) ?? false
        }
    }

    private struct CodeSummaryContent: Codable, Equatable {
        var change: PendingChange
        var applied: Bool
        var codeBlock: String?
        var explanation: String?
    }

    private struct RunAgentResult {
        let steps: [AgentStep]
        let summary: String
        let notes: [String]
        let change: PendingChange
        let explanation: String
        let codeBlock: String?
    }

    private struct StoredConversationState: Codable {
        var messages: [Message]
        var pendingChange: PendingChange?

        enum CodingKeys: String, CodingKey {
            case messages
            case pendingChange
            case pendingEdits
        }

        init(messages: [Message], pendingChange: PendingChange?) {
            self.messages = messages
            self.pendingChange = pendingChange
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            messages = try container.decode([Message].self, forKey: .messages)
            if let change = try container.decodeIfPresent(PendingChange.self, forKey: .pendingChange) {
                pendingChange = change
            } else if let oldEdits = try container.decodeIfPresent([CodeEditOperation].self, forKey: .pendingEdits),
                      oldEdits.isEmpty == false {
                pendingChange = PendingChange(edits: oldEdits)
            } else {
                pendingChange = nil
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(messages, forKey: .messages)
            try container.encodeIfPresent(pendingChange, forKey: .pendingChange)
        }
    }

    private var defaultConversation: [Message] {
        [Message(role: .assistant, content: .text(Self.introMessage))]
    }

    private func storageKey(for file: CodeFile?) -> String {
        if let id = file?.id { return "file-\(id.uuidString)" }
        return "global"
    }

    private func restoreConversationForCurrentFile() {
        isRestoringConversation = true
        defer { isRestoringConversation = false }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = conversationStore.load(for: storageKey(for: activeFile)),
           let state = try? decoder.decode(StoredConversationState.self, from: data),
           state.messages.isEmpty == false {
            conversation = state.messages
            if let change = state.pendingChange {
                pendingChange = change
            } else {
                pendingChange = pendingChangeFromConversation(state.messages)
            }
        } else {
            conversation = defaultConversation
            pendingChange = nil
        }

        prompt = ""
        errorMessage = nil
        activeAnalysisMessageID = nil
    }

    private func persistConversationState() {
        guard isRestoringConversation == false else { return }
        var inferredChange = pendingChange ?? pendingChangeFromConversation(conversation)
        if let change = inferredChange, change.edits.isEmpty && change.fullContent == nil {
            inferredChange = nil
        }
        let state = StoredConversationState(messages: conversation, pendingChange: inferredChange)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        conversationStore.save(data, for: storageKey(for: activeFile))
    }

    private func pendingChangeFromConversation(_ messages: [Message]) -> PendingChange? {
        for message in messages.reversed() {
            switch message.content {
            case .code(let codeContent) where codeContent.applied == false:
                return codeContent.change
            default:
                continue
            }
        }
        return nil
    }

    @MainActor
    private func updateAnalysisStatus(messageID: UUID, step: String) {
        guard let index = conversation.firstIndex(where: { $0.id == messageID }) else { return }
        if case .analysisStatus(var status) = conversation[index].content {
            status.currentStep = step
            conversation[index].content = .analysisStatus(status)
        }
    }

    private func applyPendingChange(for messageID: UUID) {
        guard let change = pendingChange else { return }
        onApplyChange(change)
        pendingChange = nil
        if let index = conversation.firstIndex(where: { $0.id == messageID }) {
            switch conversation[index].content {
            case .code(var codeContent):
                codeContent.applied = true
                conversation[index].content = .code(codeContent)
            case .steps(var summary):
                summary.codeApplied = true
                conversation[index].content = .steps(summary)
            default:
                break
            }
        }
        if let codeIndex = conversation.firstIndex(where: { $0.id == messageID }) {
            var searchIndex = codeIndex
            while searchIndex > conversation.startIndex {
                searchIndex = conversation.index(before: searchIndex)
                if case .steps(var summary) = conversation[searchIndex].content {
                    summary.codeApplied = true
                    conversation[searchIndex].content = .steps(summary)
                    break
                } else if case .code = conversation[searchIndex].content {
                    continue
                } else {
                    break
                }
            }
        }
        conversation.append(
            Message(
                role: .assistant,
                content: .text("Perubahan telah diterapkan ke file.")
            )
        )
        persistConversationState()
    }

    private func fileContextCard(for file: CodeFile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(file.name)
                .font(.headline)
                .foregroundStyle(.white)
            Text("Bahasa: \(file.language.displayName)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            let snippet = file.content.split(separator: Character("\n")).prefix(12).joined(separator: "\n")
            if snippet.isEmpty == false {
                Text(snippet)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(10)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text("File masih kosong.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func runAgent(prompt: String, file: CodeFile, statusUpdate: @escaping @Sendable (String) async -> Void) async throws -> RunAgentResult {
        var steps: [AgentStep] = []

        let complexity = evaluateComplexity(prompt: prompt, file: file)
        steps.append(AgentStep(title: "Profil Tugas", body: describeComplexityProfile(complexity, prompt: prompt, file: file)))

        await statusUpdate("Menafsirkan instruksi pengguna")
        try await Task.sleep(nanoseconds: 250_000_000)
        let planPrompt = buildPlanPrompt(for: prompt, file: file, complexity: complexity)
        let planResponse = try await client.generateResponse(
            messages: [],
            prompt: planPrompt,
            settings: settings
        )
        let planItems = parsePlan(from: planResponse)
        let planStepBody = formatPlanStepBody(prompt: planPrompt, response: planResponse, planItems: planItems)
        steps.append(AgentStep(title: "Rencana Analisis", body: planStepBody))

        let planOutline = planItems.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")

        var contextSummary: String
        if complexity.requiresContextAudit {
            await statusUpdate("Mengulas konteks file secara menyeluruh")
            try await Task.sleep(nanoseconds: 200_000_000)
            let contextPrompt = buildContextPrompt(for: prompt, file: file, planOutline: planOutline, complexity: complexity)
            let contextResponse = try await client.generateResponse(
                messages: [],
                prompt: contextPrompt,
                settings: settings
            )
            contextSummary = contextResponse
            steps.append(AgentStep(title: "Audit Konteks", body: formatPromptAndResponse(prompt: contextPrompt, response: contextResponse)))
        } else {
            contextSummary = "Instruksi cukup sederhana sehingga audit konteks mendalam dilewati. Fokus pada \(planItems.first ?? "tujuan utama yang disebutkan pengguna")."
            steps.append(AgentStep(title: "Audit Konteks", body: contextSummary))
        }

        await statusUpdate("Memetakan struktur file")
        try await Task.sleep(nanoseconds: 200_000_000)
        let chunkSize = complexity.chunkSize
        let chunks = makeChunks(from: file.content, size: chunkSize)
        let structureSummary = buildStructureSummary(for: file, chunkSize: chunkSize, chunkCount: chunks.count, complexity: complexity)
        steps.append(AgentStep(title: "Pemetaan Struktur File", body: structureSummary))

        var chunkDetail = "Analisis potongan mendalam tidak diperlukan berdasarkan profil kompleksitas."
        if complexity.requiresChunkAnalysis && chunks.isEmpty == false {
            await statusUpdate("Menganalisis potongan kode relevan")
            try await Task.sleep(nanoseconds: 200_000_000)

            var chunkSummaries: [ChunkSummary] = []
            var documentedChunks: [String] = []

            for chunk in chunks {
                let chunkPrompt = buildChunkPrompt(for: chunk, prompt: prompt, planOutline: planOutline, contextSummary: contextSummary, complexity: complexity)
                let chunkResponse = try await client.generateResponse(
                    messages: [],
                    prompt: chunkPrompt,
                    settings: settings
                )
                chunkSummaries.append(
                    ChunkSummary(index: chunk.index, startLine: chunk.startLine, endLine: chunk.endLine, summary: chunkResponse)
                )
                if documentedChunks.count < complexity.documentedChunkLimit {
                    documentedChunks.append(formatChunkPromptAndResponse(chunk: chunk, prompt: chunkPrompt, response: chunkResponse))
                }
            }

            let relevantDetails = chunkSummaries
                .filter { summary in
                    summary.summary.range(of: "tidak relevan", options: [.caseInsensitive, .diacriticInsensitive]) == nil
                }
                .map {
                    "• Baris \($0.startLine)-\($0.endLine):\n\($0.summary)"
                }
                .joined(separator: "\n\n")
            chunkDetail = relevantDetails.isEmpty
                ? "Model tidak menandai potongan spesifik untuk diubah. Gunakan rencana dan strategi sebagai panduan utama."
                : relevantDetails

            var chunkStepBody = documentedChunks.joined(separator: "\n\n")
            if chunkStepBody.isEmpty {
                chunkStepBody = "Tidak ada potongan yang dianggap relevan oleh model untuk dianalisis."
            }
            if chunkSummaries.count > complexity.documentedChunkLimit {
                chunkStepBody += "\n\nCatatan: \(chunkSummaries.count - complexity.documentedChunkLimit) potongan tambahan dianalisis namun tidak ditampilkan agar ringkas."
            }
            steps.append(AgentStep(title: "Analisis Potongan Relevan", body: chunkStepBody))
        } else {
            chunkDetail = "Analisis potongan diabaikan karena \(complexity.skipAnalysisReason)."
            steps.append(AgentStep(title: "Analisis Potongan Relevan", body: chunkDetail))
        }

        await statusUpdate("Menyusun strategi perubahan")
        try await Task.sleep(nanoseconds: 200_000_000)
        let strategyPrompt = buildStrategyPrompt(
            for: prompt,
            planOutline: planOutline,
            contextSummary: contextSummary,
            chunkDetail: chunkDetail,
            complexity: complexity
        )
        let strategyResponse = try await client.generateResponse(
            messages: [],
            prompt: strategyPrompt,
            settings: settings
        )
        steps.append(AgentStep(title: "Strategi Perubahan", body: formatPromptAndResponse(prompt: strategyPrompt, response: strategyResponse)))

        await statusUpdate("Menciptakan kode HTML final")
        try await Task.sleep(nanoseconds: 200_000_000)
        let contextSnippet = makeContextSnippet(from: file.content, maxCharacters: 8000)
        let planOutlineForCode = planOutline.isEmpty ? planResponse : planOutline
        let codePrompt = buildCodePrompt(
            for: prompt,
            planOutline: planOutlineForCode,
            strategy: strategyResponse,
            contextSummary: contextSummary,
            chunkDetail: chunkDetail,
            contextSnippet: contextSnippet,
            complexity: complexity
        )
        let codeResponse = try await client.generateResponse(
            messages: [],
            prompt: codePrompt,
            settings: settings
        )

        guard var htmlCode = extractHTMLCode(from: codeResponse) else {
            steps.append(AgentStep(title: "Generasi HTML", body: formatPromptAndResponse(prompt: codePrompt, response: codeResponse)))
            return RunAgentResult(
                steps: steps,
                summary: "Model tidak mengembalikan kode HTML yang dapat dipakai.",
                notes: ["Kompleksitas tugas: \(complexity.level.label) (skor \(complexity.score))."],
                change: PendingChange(),
                explanation: "Model tidak mengembalikan kode HTML yang dapat dipakai.",
                codeBlock: nil
            )
        }
        var htmlBlock = "```html\n\(htmlCode)\n```"
        steps.append(AgentStep(title: "Generasi HTML", body: formatPromptAndResponse(prompt: codePrompt, response: "Kode HTML dikirim sebagai balasan terpisah dalam format ```html```.")))

        let initialValidation = validateHTMLStructure(htmlCode)
        steps.append(
            AgentStep(
                title: "Validasi HTML",
                body: describeValidationResult(initialValidation)
            )
        )

        var notes: [String] = [
            "Kompleksitas tugas: \(complexity.level.label) (skor \(complexity.score)).",
            "Audit konteks: \(complexity.requiresContextAudit ? "dijalankan" : "dilewati").",
            "Analisis potongan: \(complexity.requiresChunkAnalysis ? "dijalankan" : "dilewati").",
            "Ukuran potongan analisis: \(chunkSize) baris."
        ]

        if initialValidation.isValid == false {
            await statusUpdate("Memperbaiki struktur HTML")
            try await Task.sleep(nanoseconds: 150_000_000)
            let repairPrompt = buildRepairPrompt(for: prompt, originalHTML: htmlCode, issues: initialValidation.issues)
            let repairResponse = try await client.generateResponse(
                messages: [],
                prompt: repairPrompt,
                settings: settings
            )
            steps.append(AgentStep(title: "Perbaikan Struktur HTML", body: formatPromptAndResponse(prompt: repairPrompt, response: repairResponse)))
            if let repairedHTML = extractHTMLCode(from: repairResponse) {
                htmlCode = repairedHTML
                htmlBlock = "```html\n\(htmlCode)\n```"
                let repairValidation = validateHTMLStructure(htmlCode)
                steps.append(
                    AgentStep(
                        title: "Validasi Setelah Perbaikan",
                        body: describeValidationResult(repairValidation)
                    )
                )
                if repairValidation.isValid == false {
                    notes.append("Perbaikan otomatis gagal menghasilkan HTML yang valid.")
                    return RunAgentResult(
                        steps: steps,
                        summary: "Perbaikan otomatis gagal menghasilkan HTML yang valid. Tinjau langkah validasi.",
                        notes: notes,
                        change: PendingChange(),
                        explanation: "Perbaikan otomatis gagal menghasilkan HTML yang valid. Tinjau langkah validasi.",
                        codeBlock: htmlBlock
                    )
                }
                notes.append("Perbaikan struktur otomatis berhasil.")
            } else {
                steps.append(
                    AgentStep(
                        title: "Validasi Setelah Perbaikan",
                        body: "Model gagal mengembalikan blok kode HTML pada upaya perbaikan."
                    )
                )
                notes.append("Model gagal mengembalikan kode HTML pada tahap perbaikan.")
                return RunAgentResult(
                    steps: steps,
                    summary: "Perbaikan otomatis gagal menghasilkan HTML yang valid.",
                    notes: notes,
                    change: PendingChange(),
                    explanation: "Perbaikan otomatis gagal menghasilkan HTML yang valid.",
                    codeBlock: nil
                )
            }
        }

        await statusUpdate("Menjelaskan kode yang dibuat")
        try await Task.sleep(nanoseconds: 150_000_000)
        let explanationPrompt = buildExplanationPrompt(htmlCode: htmlCode, prompt: prompt, planOutline: planOutline, complexity: complexity)
        let explanationRaw = try await client.generateResponse(
            messages: [],
            prompt: explanationPrompt,
            settings: settings
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let explanationResponse = explanationRaw.isEmpty ? "Model tidak mengembalikan penjelasan untuk kode yang dibuat." : explanationRaw
        steps.append(AgentStep(title: "Penjelasan Kode", body: formatPromptAndResponse(prompt: explanationPrompt, response: explanationResponse)))

        let summaryText = explanationResponse.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        return RunAgentResult(
            steps: steps,
            summary: summaryText,
            notes: notes,
            change: PendingChange(edits: [], fullContent: htmlCode),
            explanation: explanationResponse,
            codeBlock: htmlBlock
        )
    }

    private struct ComplexityProfile {
        enum Level: String {
            case low
            case medium
            case high

            var label: String {
                switch self {
                case .low: return "Rendah"
                case .medium: return "Menengah"
                case .high: return "Tinggi"
                }
            }

            var description: String {
                switch self {
                case .low: return "Permintaan fokus dan ruang lingkup terbatas."
                case .medium: return "Perubahan mencakup beberapa aspek dan membutuhkan penelusuran konteks."
                case .high: return "Instruksi kompleks, kemungkinan menyentuh banyak bagian dan membutuhkan evaluasi mendalam."
                }
            }

            var planStepRange: ClosedRange<Int> {
                switch self {
                case .low: return 4...5
                case .medium: return 5...7
                case .high: return 7...9
                }
            }
        }

        let level: Level
        let score: Int
        let wordCount: Int
        let directiveCount: Int
        let fileLineCount: Int
        let chunkSize: Int
        let requiresContextAudit: Bool
        let requiresChunkAnalysis: Bool
        let documentedChunkLimit: Int
        let attentionPhrases: [String]
        let skipAnalysisReason: String
    }

    private func evaluateComplexity(prompt: String, file: CodeFile) -> ComplexityProfile {
        let wordCount = prompt.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let directiveCount = max(prompt.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }.count, 1)
        let lineCount = file.content.lineCount

        var score = 0
        if wordCount > 80 {
            score += 3
        } else if wordCount > 50 {
            score += 2
        } else if wordCount > 25 {
            score += 1
        }

        if directiveCount > 4 {
            score += 2
        } else if directiveCount > 2 {
            score += 1
        }

        if lineCount > 220 {
            score += 3
        } else if lineCount > 140 {
            score += 2
        } else if lineCount > 70 {
            score += 1
        }

        let keywordGroups: [(keywords: [String], increment: Int, label: String)] = [
            (["refactor", "arsitektur", "architecture", "struktur"], 2, "struktur & arsitektur"),
            (["komponen", "component", "modular", "reusable"], 1, "komponen ulang"),
            (["gaya", "style", "css", "responsive"], 1, "gaya visual"),
            (["animasi", "interaksi", "transisi"], 1, "interaksi / animasi"),
            (["optimisasi", "performance", "aksesibilitas", "seo"], 2, "optimisasi & aksesibilitas"),
            (["integrasi", "api", "data", "fetch"], 2, "integrasi data")
        ]

        var attentionPhrases: [String] = []
        for group in keywordGroups {
            if group.keywords.contains(where: { prompt.localizedCaseInsensitiveContains($0) }) {
                score += group.increment
                attentionPhrases.append(group.label)
            }
        }

        let level: ComplexityProfile.Level
        if score <= 2 {
            level = .low
        } else if score <= 5 {
            level = .medium
        } else {
            level = .high
        }

        let chunkSize: Int
        switch level {
        case .low: chunkSize = 200
        case .medium: chunkSize = 150
        case .high: chunkSize = 110
        }

        let requiresContextAudit = level != .low || lineCount > 150
        let requiresChunkAnalysis = (level != .low && lineCount > 40) || lineCount > 200
        let documentedChunkLimit = level == .high ? 6 : (level == .medium ? 4 : 0)
        let skipAnalysisReason = requiresChunkAnalysis ? "" : "instruksi fokus dan ukuran file \(lineCount) baris masih mudah dibaca tanpa pemecahan potongan"

        return ComplexityProfile(
            level: level,
            score: score,
            wordCount: wordCount,
            directiveCount: directiveCount,
            fileLineCount: lineCount,
            chunkSize: chunkSize,
            requiresContextAudit: requiresContextAudit,
            requiresChunkAnalysis: requiresChunkAnalysis,
            documentedChunkLimit: documentedChunkLimit,
            attentionPhrases: attentionPhrases,
            skipAnalysisReason: skipAnalysisReason
        )
    }

    private func describeComplexityProfile(_ profile: ComplexityProfile, prompt: String, file: CodeFile) -> String {
        let attention = profile.attentionPhrases.isEmpty ? "-" : profile.attentionPhrases.joined(separator: ", ")
        let stages = [
            "Rencana analisis",
            profile.requiresContextAudit ? "Audit konteks" : "Audit konteks (dilewati)",
            "Pemetaan struktur",
            profile.requiresChunkAnalysis ? "Analisis potongan relevan" : "Analisis potongan (dilewati)",
            "Strategi perubahan",
            "Generasi HTML",
            "Validasi struktur",
            "Penjelasan akhir"
        ].joined(separator: " → ")

        return """
        Tingkat kompleksitas: \(profile.level.label) (skor heuristik \(profile.score)).
        \(profile.level.description)
        Panjang instruksi: \(profile.wordCount) kata dalam \(profile.directiveCount) kalimat/arah.
        Ukuran file aktif: \(profile.fileLineCount) baris (\(file.language.displayName)).
        Fokus utama yang terdeteksi: \(attention)
        Tahapan eksekusi: \(stages)
        """
    }

    private func buildPlanPrompt(for prompt: String, file: CodeFile, complexity: ComplexityProfile) -> String {
        let range = complexity.level.planStepRange
        let attention = complexity.attentionPhrases.isEmpty ? "Tetap fokus pada hasil akhir pengguna." : "Berikan perhatian khusus pada: \(complexity.attentionPhrases.joined(separator: ", "))."
        return """
        Kamu adalah asisten coding tingkat lanjut. Instruksi pengguna:
        "\(prompt)"

        Profil tugas:
        - Tingkat kompleksitas: \(complexity.level.label) (skor \(complexity.score)).
        - File aktif: \(file.name) (\(file.content.lineCount) baris, bahasa \(file.language.displayName)).
        - Fokus utama: \(attention)

        Buat rencana kerja bernomor sebanyak \(range.lowerBound)-\(range.upperBound) langkah dan sesuaikan jumlah langkah dengan tingkat kesulitan tugas.
        Setiap langkah wajib menjelaskan:
        • Tujuan spesifik.
        • Area kode yang akan ditinjau (fungsi, komponen, atau sekumpulan baris).
        • Pengecekan/risiko yang perlu diperhatikan.

        Pastikan rencana bersifat kronologis dan siap dieksekusi pada tahap berikutnya.
        """
    }

    private func buildContextPrompt(for prompt: String, file: CodeFile, planOutline: String, complexity: ComplexityProfile) -> String {
        let truncatedContent = truncateForPrompt(file.content, limit: 6000)
        let planSection = planOutline.isEmpty ? "Rencana belum tersedia, gunakan pemahamanmu terhadap instruksi." : planOutline
        return """
        Instruksi pengguna:
        "\(prompt)"

        Rencana analisis saat ini:
        \(planSection)

        Berikut isi file \(file.name) (dipangkas agar muat):
        ```html
        \(truncatedContent)
        ```

        Tugasmu:
        1. Ringkas struktur utama file dan bagian penting terkait instruksi.
        2. Identifikasi area yang berpotensi dipengaruhi perubahan (sebutkan baris atau penanda struktur).
        3. Soroti risiko atau dependensi yang perlu dijaga.

        Jawab secara ringkas namun informatif.
        """
    }

    private func buildStructureSummary(for file: CodeFile, chunkSize: Int, chunkCount: Int, complexity: ComplexityProfile) -> String {
        """
        Struktur file:
        • Total baris: \(file.content.lineCount)
        • Jumlah potongan evaluasi: \(chunkCount) (maks \(chunkSize) baris per potongan)
        • Bahasa dominan: \(file.language.displayName)
        • Profil kompleksitas: \(complexity.level.label)
        """
    }

    private func buildChunkPrompt(for chunk: Chunk, prompt: String, planOutline: String, contextSummary: String, complexity: ComplexityProfile) -> String {
        let trimmedPlan = planOutline.isEmpty ? "-" : planOutline
        let trimmedContext = truncateForPrompt(contextSummary, limit: 1200)
        let trimmedChunk = truncateForPrompt(chunk.text, limit: 1500)
        return """
        Instruksi pengguna:
        "\(prompt)"

        Rencana analisis:
        \(trimmedPlan)

        Ringkasan konteks (dipangkas):
        \(trimmedContext)

        Evaluasi potongan kode baris \(chunk.startLine)-\(chunk.endLine):
        \(trimmedChunk)

        Tugasmu:
        1. Jelaskan apakah potongan relevan dengan instruksi.
        2. Jika relevan, sebutkan bagian mana yang harus berubah dan alasannya.
        3. Jika tidak relevan, jawab singkat "Tidak relevan karena ..." (maksimum 1 kalimat).
        4. Jangan mengusulkan perubahan kode di tahap ini, hanya analisis.
        """
    }

    private func formatChunkPromptAndResponse(chunk: Chunk, prompt: String, response: String) -> String {
        """
        [Potongan \(chunk.index + 1) • Baris \(chunk.startLine)-\(chunk.endLine)]
        Prompt:
        \(prompt)

        Jawaban:
        \(response)
        """
    }

    private func buildStrategyPrompt(for prompt: String, planOutline: String, contextSummary: String, chunkDetail: String, complexity: ComplexityProfile) -> String {
        let trimmedPlan = planOutline.isEmpty ? "-" : planOutline
        let trimmedContext = truncateForPrompt(contextSummary, limit: 2000)
        let trimmedChunk = truncateForPrompt(chunkDetail, limit: 2000)
        let maxPoints = complexity.level == .high ? 6 : 5
        return """
        Instruksi pengguna:
        "\(prompt)"

        Rencana analisis:
        \(trimmedPlan)

        Ringkasan konteks:
        \(trimmedContext)

        Temuan analisis potongan:
        \(trimmedChunk)

        Susun strategi perubahan yang terstruktur sebagai daftar poin (maksimal \(maxPoints) poin). Setiap poin wajib mencakup:
        - Tujuan spesifik.
        - Area kode yang terpengaruh (sebutkan baris, elemen HTML, atau struktur).
        - Risiko atau pengecekan yang perlu dilakukan setelah perubahan.
        """
    }

    private func buildCodePrompt(for prompt: String, planOutline: String, strategy: String, contextSummary: String, chunkDetail: String, contextSnippet: String, complexity: ComplexityProfile) -> String {
        let trimmedPlan = truncateForPrompt(planOutline, limit: 2500)
        let trimmedStrategy = truncateForPrompt(strategy, limit: 2500)
        let trimmedContext = truncateForPrompt(contextSummary, limit: 2000)
        let trimmedChunk = truncateForPrompt(chunkDetail, limit: 2000)
        let completenessNote = complexity.level == .high ? "Pastikan kode final siap produksi dan tidak menyisakan placeholder." : "Pastikan kode final bisa dijalankan tanpa error."
        return """
        Instruksi pengguna:
        "\(prompt)"

        Rencana analisis:
        \(trimmedPlan)

        Strategi perubahan:
        \(trimmedStrategy)

        Ringkasan konteks:
        \(trimmedContext)

        Detil potongan relevan:
        \(trimmedChunk)

        Berikut isi file sebelum perubahan (dipangkas):
        ```html
        \(contextSnippet)
        ```

        Hasilkan file HTML final yang sudah dirapikan dengan menerapkan instruksi di atas. Terapkan seluruh strategi, jaga konsistensi struktur, dan pertahankan bagian yang tidak perlu diubah.
        Format jawaban sebagai blok kode Markdown tunggal dengan label ```html dan tanpa teks tambahan di luar blok tersebut. Jika perlu menyisipkan JavaScript atau CSS, sertakan di dalam dokumen HTML tersebut. \(completenessNote)
        """
    }

    private func buildRepairPrompt(for prompt: String, originalHTML: String, issues: [String]) -> String {
        let issueText = issues.isEmpty ? "- Struktur dasar belum lengkap." : issues.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
        let trimmedHTML = truncateForPrompt(originalHTML, limit: 6000)
        return """
        Berikut instruksi pengguna:
        "\(prompt)"

        Kode HTML yang kamu hasilkan belum valid. Masalah yang ditemukan:
        \(issueText)

        Berikut kode yang perlu diperbaiki:
        ```html
        \(trimmedHTML)
        ```

        Perbaiki kode tersebut sehingga:
        1. Mengandung <!DOCTYPE html>, <html>, <head>, dan <body> yang berpasangan.
        2. Struktur semantik tetap rapi dan sesuai instruksi awal.
        3. Konten penting dari versi sebelumnya tidak hilang tanpa alasan yang jelas.

        Berikan hasil akhir sebagai blok kode ```html tanpa penjelasan tambahan.
        """
    }

    private func buildExplanationPrompt(htmlCode: String, prompt: String, planOutline: String, complexity: ComplexityProfile) -> String {
        let trimmedPlan = planOutline.isEmpty ? "-" : truncateForPrompt(planOutline, limit: 1500)
        let trimmedHTML = truncateForPrompt(htmlCode, limit: 4000)
        let sentenceTarget = complexity.level == .high ? "4-5 kalimat" : "3-4 kalimat"
        return """
        Kamu baru saja menyusun dokumen HTML berikut:

        ```html
        \(trimmedHTML)
        ```

        Instruksi pengguna:
        "\(prompt)"

        Rencana yang telah disusun:
        \(trimmedPlan)

        Jelaskan isi kode tersebut dalam \(sentenceTarget) menggunakan bahasa Indonesia yang jelas. Fokus pada:
        - Struktur halaman dan bagian utamanya.
        - Perubahan penting dibandingkan versi sebelumnya.
        - Manfaat atau efek yang diperoleh pengguna akhir.

        Hindari bullet, daftar, atau blok kode tambahan.
        """
    }

    private func formatPlanStepBody(prompt: String, response: String, planItems: [String]) -> String {
        var body = formatPromptAndResponse(prompt: prompt, response: response)
        if planItems.isEmpty == false {
            let enumerated = planItems.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
            body += "\n\nLangkah terstruktur:\n\(enumerated)"
        }
        return body
    }

    private func formatPromptAndResponse(prompt: String, response: String) -> String {
        """
        Prompt:
        \(prompt)

        Jawaban:
        \(response)
        """
    }

    private func truncateForPrompt(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let suffixLength = min(400, limit / 3)
        let prefixLength = limit - suffixLength - 5
        let prefix = text.prefix(prefixLength)
        let suffix = text.suffix(suffixLength)
        return "\(prefix)\n...\n\(suffix)"
    }

    private func parsePlan(from response: String) -> [String] {
        let lines = response.split(separator: "\n", omittingEmptySubsequences: false)
        var items: [String] = []
        var current: String?

        for rawLine in lines {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.range(of: "^\\d+", options: .regularExpression) != nil {
                if let existing = current?.trimmingCharacters(in: .whitespacesAndNewlines), existing.isEmpty == false {
                    items.append(existing)
                }
                let cleaned = trimmed.replacingOccurrences(of: "^\\d+[\\).:-]?\\s*", with: "", options: .regularExpression)
                current = cleaned
            } else if trimmed.isEmpty == false {
                if current != nil {
                    current! += "\n" + trimmed
                } else {
                    current = trimmed
                }
            }
        }

        if let existing = current?.trimmingCharacters(in: .whitespacesAndNewlines), existing.isEmpty == false {
            items.append(existing)
        }
        return items
    }

    private func extractHTMLCode(from response: String) -> String? {
        if let range = response.range(of: "```html", options: [.caseInsensitive]) {
            let rest = response[range.upperBound...]
            if let end = rest.range(of: "```") {
                let snippet = rest[..<end.lowerBound]
                return snippet.replacingOccurrences(of: "\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let genericRange = response.range(of: "```") {
            let rest = response[genericRange.upperBound...]
            if let end = rest.range(of: "```") {
                let snippet = rest[..<end.lowerBound]
                return snippet.replacingOccurrences(of: "\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    private func makeContextSnippet(from content: String, maxCharacters: Int) -> String {
        guard content.count > maxCharacters else { return content }
        let prefixLength = maxCharacters / 2
        let suffixLength = maxCharacters - prefixLength
        let startIndex = content.startIndex
        let endIndex = content.endIndex
        let prefix = content[startIndex..<content.index(startIndex, offsetBy: prefixLength)]
        let suffix = content[content.index(endIndex, offsetBy: -suffixLength)..<endIndex]
        return "\(prefix)\n...\n\(suffix)"
    }

    private struct HTMLValidationResult {
        let isValid: Bool
        let issues: [String]
    }

    private func validateHTMLStructure(_ code: String) -> HTMLValidationResult {
        let lowercased = code.lowercased()
        var issues: [String] = []

        if lowercased.contains("<!doctype html") == false {
            issues.append("Tidak menemukan <!DOCTYPE html>.")
        }
        if lowercased.contains("<html") == false || lowercased.contains("</html>") == false {
            issues.append("Tag <html> atau </html> hilang.")
        }
        if lowercased.contains("<head") == false || lowercased.contains("</head>") == false {
            issues.append("Bagian <head> belum lengkap.")
        }
        if lowercased.contains("<body") == false || lowercased.contains("</body>") == false {
            issues.append("Bagian <body> belum lengkap.")
        }

        return HTMLValidationResult(isValid: issues.isEmpty, issues: issues)
    }

    private func describeValidationResult(_ result: HTMLValidationResult) -> String {
        if result.isValid {
            return "Struktur HTML memenuhi elemen dasar (doctype, html, head, body)."
        }
        let issueText = result.issues.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
        return """
        Struktur HTML belum valid. Temuan:
        \(issueText)
        """
    }

    private func makeChunks(from content: String, size: Int) -> [Chunk] {
        let lines = content.components(separatedBy: .newlines)
        if lines.count == 1 && lines.first?.isEmpty == true {
            return []
        }

        var chunks: [Chunk] = []
        var start = 0
        while start < lines.count {
            let end = min(start + size, lines.count)
            let slice = lines[start..<end]
            let text = slice.joined(separator: "\n")
            chunks.append(
                Chunk(index: chunks.count, startLine: start + 1, endLine: end, text: text)
            )
            start = end
        }
        return chunks
    }

    private struct AgentStep: Identifiable, Codable, Equatable {
        let id: UUID
        let title: String
        let body: String

        init(id: UUID = UUID(), title: String, body: String) {
            self.id = id
            self.title = title
            self.body = body
        }
    }

    private struct Chunk {
        let index: Int
        let startLine: Int
        let endLine: Int
        let text: String
    }

    private struct ChunkSummary {
        let index: Int
        let startLine: Int
        let endLine: Int
        let summary: String
    }

    private struct AnalysisStatusView: View {
        let startedAt: Date
        let currentStep: String

        var body: some View {
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                let seconds = max(Int(context.date.timeIntervalSince(startedAt).rounded()), 0)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white.opacity(0.8))
                        Text("AI sedang berpikir • \(seconds)s")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Text(currentStep)
                        .font(.footnote)
                        .foregroundStyle(DashboardTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private struct StepSummaryBubble: View {
        let summary: StepSummaryContent

        @State private var showSteps = false
        @State private var expandedSteps: Set<UUID> = []

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                Text("Seditor AI selesai dalam \(formatted(duration: summary.duration)).")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(DashboardTheme.textSecondary)

                Text(summary.summaryText)
                    .font(.subheadline)
                    .foregroundStyle(DashboardTheme.textPrimary)

                if summary.codeApplied == false {
                    Text("Patch perubahan disediakan pada balasan berikutnya. Gunakan tombol Terapkan setelah meninjau.")
                        .font(.footnote)
                        .foregroundStyle(DashboardTheme.textSecondary)
                }

                if summary.steps.isEmpty == false {
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showSteps.toggle()
                                if showSteps == false {
                                    expandedSteps.removeAll()
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: showSteps ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                Text(showSteps ? "Sembunyikan langkah analisis" : "Tampilkan langkah analisis")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DashboardTheme.textSecondary)

                        if showSteps {
                            VStack(spacing: 12) {
                                ForEach(summary.steps) { step in
                                    StepItemView(
                                        step: step,
                                        isExpanded: expandedSteps.contains(step.id),
                                        onToggle: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if expandedSteps.contains(step.id) {
                                                    expandedSteps.remove(step.id)
                                                } else {
                                                    expandedSteps.insert(step.id)
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                if summary.notes.isEmpty == false {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(summary.notes.enumerated()), id: \.offset) { item in
                            Text("• \(item.element)")
                                .font(.footnote)
                                .foregroundStyle(DashboardTheme.textSecondary)
                        }
                    }
                }

                if summary.codeApplied {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("Perubahan telah diterapkan ke file.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private func formatted(duration: TimeInterval) -> String {
            let totalSeconds = Int(duration.rounded())
            if totalSeconds < 60 {
                return "\(totalSeconds)s"
            }
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return "\(minutes)m \(seconds)s"
        }
    }

    private struct CodeChangeBubble: View {
        let content: CodeSummaryContent
        let onApply: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                if let explanation = content.explanation, explanation.isEmpty == false {
                    Text(explanation)
                        .font(.subheadline)
                        .foregroundStyle(DashboardTheme.textPrimary)
                }

                if let codeBlock = content.codeBlock, codeBlock.isEmpty == false {
                    Text("Pratinjau Isi File Baru")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DashboardTheme.textPrimary)
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(codeBlock)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(DashboardTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 220)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if let full = content.change.fullContent, content.change.edits.isEmpty {
                    Text("Pratinjau Isi File Baru")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DashboardTheme.textPrimary)
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(full)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(DashboardTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 220)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if content.change.edits.isEmpty == false {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(content.change.edits, id: \.self) { edit in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Baris \(edit.startLine)-\(edit.endLine)")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(DashboardTheme.textPrimary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    Text(edit.replacement.isEmpty ? "(hapus baris ini)" : edit.replacement)
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundStyle(DashboardTheme.textSecondary)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }

                if content.applied {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("Perubahan telah diterapkan ke file.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                } else if content.change.edits.isEmpty && content.change.fullContent == nil {
                    Text("AI tidak dapat menyusun patch otomatis dari respons ini.")
                        .font(.footnote)
                        .foregroundStyle(DashboardTheme.textSecondary)
                } else {
                    Button(action: onApply) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Terapkan ke file")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentBlue)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct StepItemView: View {
        let step: AgentStep
        let isExpanded: Bool
        let onToggle: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Button(action: onToggle) {
                    HStack {
                        Text(step.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DashboardTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .foregroundStyle(.white.opacity(0.7))
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Text(step.body)
                        .font(.callout)
                        .foregroundStyle(DashboardTheme.textPrimary.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

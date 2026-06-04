import SwiftUI
import FoundationModels

// MARK: - AI Suggested Task

struct AITask: Identifiable {
    let id = UUID()
    var title: String
    var time: String?
    var priority: TodoPriority
    var note: String
    var isSelected: Bool = true
}

// MARK: - KI Tagesplan Sheet

struct KITagesplanSheet: View {
    let todos: [TodoItem]
    let selectedDate: Date
    let themeC1: Color
    let themeC2: Color

    @EnvironmentObject var todoStore: TodoStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var generatedText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var usedSource: AISource = .none

    // Task extraction
    @State private var suggestedTasks: [AITask] = []
    @State private var isExtractingTasks = false
    @State private var addedTaskIDs: Set<UUID> = []
    @AppStorage("aiProvider") private var aiProvider: String = "gemini"
    @AppStorage("openaiSelectedModel") private var openaiSelectedModel: String = OpenAIService.models[0]
    @AppStorage("groqSelectedModel")   private var groqSelectedModel:   String = GroqService.models[0]

    // Inline key setup
    @State private var keyInput: String = ""
    @State private var keyVisible: Bool = false
    @State private var keySaving: Bool = false
    @State private var showSetup: Bool = false
    @State private var showGuide: Bool = false

    // Prompt input
    @State private var userPrompt: String = ""
    @ObservedObject private var bausteinStore = BausteinStore.shared
    @ObservedObject private var speech = SpeechManager.shared
    @AppStorage("selectedLanguage") private var selectedLanguage = "Deutsch"
    @AppStorage("aiAutoSpeak")      private var aiAutoSpeak: Bool = false

    private var speechLang: String { selectedLanguage == "Deutsch" ? "de-DE" : "en-US" }
    @State private var lastSpokenLength = 0
    private var isDark: Bool { colorScheme == .dark }
    private var cal: Calendar { Calendar.current }
    private var hasKey: Bool {
        switch aiProvider {
        case "openai": return KeychainHelper.load(for: OpenAIService.keychainKey) != nil
        case "groq":   return KeychainHelper.load(for: GroqService.keychainKey) != nil
        default:       return KeychainHelper.load(for: GeminiService.keychainKey) != nil
        }
    }

    private var appleIntelligenceAvailable: Bool {
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        return false
    }

    private var setupTitle: String {
        switch aiProvider {
        case "openai": return "OpenAI API Key"
        case "groq":   return "Groq API Key"
        default:       return String(localized: "ki_setup_title")
        }
    }
    private var setupDesc: String {
        switch aiProvider {
        case "openai": return String(localized: "openai_setup_desc")
        case "groq":   return String(localized: "groq_setup_desc")
        default:       return String(localized: "ki_setup_desc")
        }
    }
    private var setupPlaceholder: String {
        switch aiProvider {
        case "openai": return "sk-..."
        case "groq":   return "gsk_..."
        default:       return "AIza..."
        }
    }

    private var providerLabel: String {
        switch aiProvider {
        case "openai": return "OpenAI"
        case "groq":   return "Groq"
        case "apple":  return "Apple"
        default:       return "Gemini"
        }
    }

    private var headerTitle: String {
        switch usedSource {
        case .appleIntelligence: return "Apple Intelligence"
        case .openai:            return openaiSelectedModel
        case .groq:              return groqSelectedModel
        case .gemini:            return "Gemini 2.0 Flash"
        case .none:
            switch aiProvider {
            case "openai": return openaiSelectedModel
            case "groq":   return groqSelectedModel
            case "apple":  return "Apple Intelligence"
            default:       return "Gemini 2.0 Flash"
            }
        }
    }
    private var headerSub: String {
        switch usedSource {
        case .appleIntelligence: return String(localized: "ki_runs_locally")
        case .openai:            return String(localized: "ki_runs_openai")
        case .groq:              return String(localized: "ki_runs_groq")
        case .gemini:            return String(localized: "ki_runs_gemini")
        case .none:
            switch aiProvider {
            case "openai": return String(localized: "ki_runs_openai")
            case "groq":   return String(localized: "ki_runs_groq")
            case "apple":  return String(localized: "ki_runs_locally")
            default:       return String(localized: "ki_runs_gemini")
            }
        }
    }

    enum AISource { case none, appleIntelligence, gemini, openai, groq }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Response area (scrollable)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard
                        if showSetup {
                            setupCard
                        } else {
                            contentArea
                        }
                        Spacer(minLength: 20)
                    }
                    .padding(20)
                }

                // Fixed prompt input at the bottom
                promptInputArea
            }
            .background { ThemeBackgroundView().ignoresSafeArea() }
            .navigationTitle(String(localized: "ki_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "done")) { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Menu {
                        Picker("", selection: $aiProvider) {
                            Label("Gemini", systemImage: "sparkles").tag("gemini")
                            Label("OpenAI", systemImage: "brain").tag("openai")
                            Label("Groq", systemImage: "bolt.fill").tag("groq")
                            Label("Apple Intelligence", systemImage: "apple.logo").tag("apple")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(providerLabel)
                                .font(.headline)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.primary)
                    }
                    .onChange(of: aiProvider) { _ in
                        generatedText = ""
                        errorMessage = nil
                        showSetup = false
                        usedSource = .none
                    }
                }
            }
        }
        .onChange(of: generatedText) { text in
            guard aiAutoSpeak, isLoading else { return }
            let newPart = String(text.dropFirst(lastSpokenLength))
            guard !newPart.isEmpty else { return }
            speech.appendToStream(newPart, languageCode: speechLang)
            lastSpokenLength = text.count
        }
        .onChange(of: isLoading) { loading in
            guard !loading, aiAutoSpeak else { return }
            speech.finishStream(languageCode: speechLang)
            lastSpokenLength = 0
        }
        .sheet(isPresented: $showGuide) {
            NavigationStack {
                GeminiKeyGuideView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "done")) {
                                showGuide = false
                                // Wenn Key jetzt gesetzt, direkt generieren
                                if KeychainHelper.load(for: GeminiService.keychainKey) != nil {
                                    Task { await generate() }
                                }
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [themeC1, themeC2],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(headerTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                Text(headerSub)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .themeGlass(cornerRadius: 16)
    }

    // MARK: - Inline Setup Card

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if hasKey {
                // Key already saved — just show status + retry
                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.green)
                    Text(String(localized: "ki_key_saved_status"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isDark ? .white : .primary)
                    Spacer()
                    Button {
                        showSetup = false
                        Task { await generate() }
                    } label: {
                        Label(String(localized: "ki_retry"), systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(themeC1, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // No key — show input form
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(setupTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isDark ? .white : .primary)
                        Text(setupDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if aiProvider == "openai" {
                        Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                            Label("platform.openai.com", systemImage: "arrow.up.right.square.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.green.opacity(0.12), in: Capsule())
                        }
                    } else if aiProvider == "groq" {
                        Link(destination: URL(string: "https://console.groq.com/keys")!) {
                            Label("console.groq.com", systemImage: "arrow.up.right.square.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.orange.opacity(0.12), in: Capsule())
                        }
                    } else {
                        Button { showGuide = true } label: {
                            Label(String(localized: "gemini_guide_short_btn"), systemImage: "questionmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.purple.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    Group {
                        if keyVisible {
                            TextField(setupPlaceholder, text: $keyInput)
                        } else {
                            SecureField(setupPlaceholder, text: $keyInput)
                        }
                    }
                    .font(.system(size: 14, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                    Button { keyVisible.toggle() } label: {
                        Image(systemName: keyVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 10) {
                    Button(String(localized: "Abbrechen")) { showSetup = false }
                        .font(.subheadline).foregroundStyle(.secondary).buttonStyle(.plain)

                    Spacer()

                    Button {
                        let trimmed = keyInput.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        keySaving = true
                        let kcKey: String
                        switch aiProvider {
                        case "openai": kcKey = OpenAIService.keychainKey
                        case "groq":   kcKey = GroqService.keychainKey
                        default:       kcKey = GeminiService.keychainKey
                        }
                        KeychainHelper.save(trimmed, for: kcKey)
                        showSetup = false
                        keySaving = false
                        Task { await generate() }
                    } label: {
                        if keySaving {
                            ProgressView().scaleEffect(0.8).tint(.white)
                        } else {
                            Text(String(localized: "ki_setup_save"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(
                        keyInput.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : themeC1,
                        in: Capsule()
                    )
                    .buttonStyle(.plain)
                    .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } // end else (no key)
        }
        .padding(16)
        .themeGlass(cornerRadius: 16)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if let error = errorMessage {
            errorCard(error)
        } else if isLoading && generatedText.isEmpty {
            loadingCard
        } else if !generatedText.isEmpty {
            responseCard
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(themeC1)
            Text(String(localized: "ki_analyzing"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .themeGlass(cornerRadius: 16)
    }

    private var responseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // AI response text
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    Text(generatedText)
                        .font(.body)
                        .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)
                        .multilineTextAlignment(.leading)
                        .animation(.easeIn(duration: 0.1), value: generatedText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !isLoading && !generatedText.isEmpty {
                        Button {
                            if speech.isSpeaking { speech.stopSpeaking() }
                            else { speech.speak(generatedText, languageCode: speechLang) }
                        } label: {
                            Image(systemName: speech.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(speech.isSpeaking ? .red : themeC1)
                                .frame(width: 30, height: 30)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if isLoading {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(themeC1)
                                .frame(width: 5, height: 5)
                                .animation(
                                    .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.18),
                                    value: isLoading
                                )
                        }
                    }
                    .padding(.top, 8)
                }
            }

            // "Save as tasks" button — only when response is complete
            if !isLoading {
                Divider()
                if isExtractingTasks {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8).tint(themeC1)
                        Text(String(localized: "ki_extracting_tasks"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else if suggestedTasks.isEmpty {
                    Button {
                        Task { await extractTasks() }
                    } label: {
                        Label(String(localized: "ki_save_as_tasks"), systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(themeC1)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Suggested task cards
            if !suggestedTasks.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "ki_tasks_title"))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button {
                            let toAdd = suggestedTasks.filter { $0.isSelected && !addedTaskIDs.contains($0.id) }
                            toAdd.forEach { addTask($0) }
                        } label: {
                            Label(String(localized: "ki_add_all"), systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(themeC1, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(suggestedTasks.filter { $0.isSelected && !addedTaskIDs.contains($0.id) }.isEmpty)
                    }

                    ForEach($suggestedTasks) { $task in
                        taskRow(task: $task)
                    }
                }
            }
        }
        .padding(16)
        .themeGlass(cornerRadius: 16)
    }

    private func taskRow(task: Binding<AITask>) -> some View {
        let isAdded = addedTaskIDs.contains(task.id)
        return HStack(spacing: 10) {
            // Selection toggle
            Button {
                task.wrappedValue.isSelected.toggle()
            } label: {
                Image(systemName: task.wrappedValue.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.wrappedValue.isSelected ? themeC1 : .secondary)
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .disabled(isAdded)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.wrappedValue.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(isAdded)
                    .foregroundStyle(isAdded ? .secondary : .primary)
                HStack(spacing: 6) {
                    if let time = task.wrappedValue.time {
                        Label(time, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    priorityBadge(task.wrappedValue.priority)
                }
            }

            Spacer()

            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 20))
            } else {
                Button {
                    addTask(task.wrappedValue)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(themeC1)
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func priorityBadge(_ p: TodoPriority) -> some View {
        let (label, color): (String, Color) = switch p {
        case .high:   (String(localized: "priority_high"),   .red)
        case .medium: (String(localized: "priority_medium"), .orange)
        case .low:    (String(localized: "priority_low"),    .green)
        }
        return Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(String(localized: "ki_unavailable")).font(.subheadline.weight(.semibold))
            }
            Text(message).font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 10) {
                if hasKey {
                    // Key already saved → retry only
                    Button {
                        errorMessage = nil
                        Task { await generate() }
                    } label: {
                        Label(String(localized: "ki_retry"), systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(themeC1, in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    // No key → offer to add one
                    Button {
                        showSetup = true
                        errorMessage = nil
                    } label: {
                        Label(String(localized: "ki_add_key_button"), systemImage: "key.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(themeC1, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        showGuide = true
                    } label: {
                        Label(String(localized: "gemini_guide_short_btn"), systemImage: "questionmark.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.purple.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .themeGlass(cornerRadius: 16)
    }

    // MARK: - Prompt Input Area

    private var promptInputArea: some View {
        VStack(spacing: 0) {
            Divider()

            // Baustein chips
            if !bausteinStore.bausteine.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "Tagesplan" as default chip
                        bausteinChip(
                            icon: "calendar.badge.sparkles",
                            label: String(localized: "ki_chip_tagesplan"),
                            color: themeC1
                        ) {
                            userPrompt = ""
                            Task { await generate() }
                        }

                        ForEach(bausteinStore.bausteine.prefix(8)) { b in
                            bausteinChip(
                                icon: b.symbol,
                                label: b.titel,
                                color: b.farbe.color
                            ) {
                                userPrompt = String(localized: "ki_baustein_prompt_prefix") + " \"\(b.titel)\""
                                Task { await generate() }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(.ultraThinMaterial)
            }

            // Text input row
            HStack(spacing: 8) {
                // Mic button
                Button {
                    if speech.isRecording {
                        speech.stopRecording()
                        if !speech.liveText.isEmpty { userPrompt = speech.liveText }
                    } else {
                        speech.requestPermissions()
                        speech.startRecording(languageCode: speechLang)
                    }
                } label: {
                    Image(systemName: speech.isRecording ? "waveform" : "mic")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(speech.isRecording ? .red : .secondary)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle().stroke(speech.isRecording ? Color.red.opacity(0.4) : Color.clear, lineWidth: 1.5)
                        )
                }

                TextField(String(localized: "ki_prompt_placeholder"), text: $userPrompt, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .onChange(of: speech.liveText) { live in
                        if speech.isRecording { userPrompt = live }
                    }

                Button {
                    Task { await generate() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(width: 44, height: 44)
                            .background(themeC1, in: Circle())
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                userPrompt.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? themeC1.opacity(0.5)
                                    : themeC1,
                                in: Circle()
                            )
                    }
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    private func bausteinChip(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generation

    private func generate() async {
        isLoading = true
        errorMessage = nil
        generatedText = ""
        showSetup = false
        suggestedTasks = []
        addedTaskIDs = []
        if aiAutoSpeak { speech.resetStream() }
        lastSpokenLength = 0

        let prompt = buildPrompt()

        switch aiProvider {

        case "apple":
            if #available(iOS 26.0, *) {
                if case .available = SystemLanguageModel.default.availability {
                    usedSource = .appleIntelligence
                    do {
                        let session = LanguageModelSession()
                        let stream = session.streamResponse(to: prompt)
                        for try await partial in stream { generatedText = partial.content }
                        isLoading = false
                        return
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } else {
                    errorMessage = String(localized: "ki_apple_unavailable")
                }
            } else {
                errorMessage = String(localized: "ki_apple_requires_ios26")
            }

        case "openai":
            if let apiKey = KeychainHelper.load(for: OpenAIService.keychainKey), !apiKey.isEmpty {
                usedSource = .openai
                do {
                    let stream = OpenAIService.stream(prompt: prompt, apiKey: apiKey, model: openaiSelectedModel)
                    for try await chunk in stream { generatedText += chunk }
                    isLoading = false
                    return
                } catch {
                    if generatedText.isEmpty { errorMessage = error.localizedDescription }
                }
            } else {
                showSetup = true
            }

        case "groq":
            if let apiKey = KeychainHelper.load(for: GroqService.keychainKey), !apiKey.isEmpty {
                usedSource = .groq
                do {
                    let stream = GroqService.stream(prompt: prompt, apiKey: apiKey, model: groqSelectedModel)
                    for try await chunk in stream { generatedText += chunk }
                    isLoading = false
                    return
                } catch {
                    if generatedText.isEmpty { errorMessage = error.localizedDescription }
                }
            } else {
                showSetup = true
            }

        default: // gemini
            if let apiKey = KeychainHelper.load(for: GeminiService.keychainKey), !apiKey.isEmpty {
                usedSource = .gemini
                do {
                    let stream = GeminiService.stream(prompt: prompt, apiKey: apiKey)
                    for try await chunk in stream { generatedText += chunk }
                    isLoading = false
                    return
                } catch {
                    if generatedText.isEmpty { errorMessage = error.localizedDescription }
                }
            } else {
                showSetup = true
            }
        }

        isLoading = false
    }

    // MARK: - Task Extraction

    private func extractTasks() async {
        guard !generatedText.isEmpty else { return }
        isExtractingTasks = true
        suggestedTasks = []

        let dateStr = DateFormatter.localizedString(from: selectedDate, dateStyle: .short, timeStyle: .none)
        let extractPrompt = """
        Extract all tasks and activities from the following text. Return ONLY a valid JSON array, no other text.
        Format: [{"title":"...","time":"HH:MM or null","priority":"low|medium|high","note":"brief description or empty"}]
        Date context: \(dateStr)

        Text:
        \(generatedText)
        """

        var raw = ""
        do {
            switch aiProvider {
            case "apple":
                if #available(iOS 26.0, *) {
                    if case .available = SystemLanguageModel.default.availability {
                        let session = LanguageModelSession()
                        let stream = session.streamResponse(to: extractPrompt)
                        for try await partial in stream { raw = partial.content }
                    }
                }
            case "openai":
                if let key = KeychainHelper.load(for: OpenAIService.keychainKey) {
                    let stream = OpenAIService.stream(prompt: extractPrompt, apiKey: key, model: openaiSelectedModel)
                    for try await chunk in stream { raw += chunk }
                }
            case "groq":
                if let key = KeychainHelper.load(for: GroqService.keychainKey) {
                    let stream = GroqService.stream(prompt: extractPrompt, apiKey: key, model: groqSelectedModel)
                    for try await chunk in stream { raw += chunk }
                }
            default: // gemini
                if let key = KeychainHelper.load(for: GeminiService.keychainKey) {
                    let stream = GeminiService.stream(prompt: extractPrompt, apiKey: key)
                    for try await chunk in stream { raw += chunk }
                }
            }
        } catch {}

        suggestedTasks = parseAITasks(from: raw, date: selectedDate)
        isExtractingTasks = false
    }

    private func parseAITasks(from raw: String, date: Date) -> [AITask] {
        // Extract JSON array from response (AI might add markdown code blocks)
        var json = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = json.range(of: "["), let end = json.range(of: "]", options: .backwards) {
            json = String(json[start.lowerBound...end.upperBound])
        }
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let cal = Calendar.current
        return arr.compactMap { dict -> AITask? in
            guard let title = dict["title"] as? String, !title.isEmpty else { return nil }
            let priorityStr = dict["priority"] as? String ?? "medium"
            let priority: TodoPriority = priorityStr == "high" ? .high : priorityStr == "low" ? .low : .medium
            let timeStr = dict["time"] as? String
            return AITask(
                title: title,
                time: timeStr == "null" ? nil : timeStr,
                priority: priority,
                note: dict["note"] as? String ?? ""
            )
        }
    }

    private func addTask(_ task: AITask) {
        let cal = Calendar.current
        var dueDate: Date? = nil
        if let timeStr = task.time,
           let colonIdx = timeStr.firstIndex(of: ":") {
            let h = Int(timeStr[timeStr.startIndex..<colonIdx]) ?? 9
            let m = Int(timeStr[timeStr.index(after: colonIdx)...]) ?? 0
            dueDate = cal.date(bySettingHour: h, minute: m, second: 0, of: selectedDate)
        } else {
            dueDate = cal.startOfDay(for: selectedDate)
        }
        var item = TodoItem(
            title: task.title,
            description: task.note,
            dueDate: dueDate,
            priority: task.priority
        )
        todoStore.addTodo(item)
        addedTaskIDs.insert(task.id)
    }

    // MARK: - Prompt

    private func buildPrompt() -> String {
        let trimmed = userPrompt.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            let dayTodos = todos.filter {
                guard let due = $0.dueDate else { return false }
                return cal.isDate(due, inSameDayAs: selectedDate)
            }.filter { !$0.isCompleted }
            let taskHint = dayTodos.isEmpty ? "" : "\n\nMy tasks today: " + dayTodos.prefix(5).map { $0.title }.joined(separator: ", ") + "."
            return """
            Respond in 1–3 sentences, direct and without filler phrases. No Markdown.
            \(trimmed)\(taskHint)
            """
        }

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale.current
        dateFmt.dateFormat = "EEEE, MMMM d, yyyy"

        let timeFmt = DateFormatter()
        timeFmt.locale = Locale.current
        timeFmt.dateFormat = "HH:mm"

        let dayTodos = todos.filter {
            guard let due = $0.dueDate else { return false }
            return cal.isDate(due, inSameDayAs: selectedDate)
        }
        let open = dayTodos.filter { !$0.isCompleted }
        let done  = dayTodos.filter {  $0.isCompleted }

        return buildEnglishPrompt(dateString: dateFmt.string(from: selectedDate), tf: timeFmt, open: open, done: done)
    }

    private func buildEnglishPrompt(dateString: String, tf: DateFormatter,
                                    open: [TodoItem], done: [TodoItem]) -> String {
        var lines = ""
        if !open.isEmpty {
            lines += "Open tasks:\n"
            for t in open {
                let time = t.dueDate.map { tf.string(from: $0) } ?? "–"
                let end  = t.endDate.map { " to \(tf.string(from: $0))" } ?? ""
                lines += "- \(t.title) (\(time)\(end))\n"
            }
        }
        if !done.isEmpty {
            lines += "\nAlready done:\n"
            for t in done { lines += "- \(t.title)\n" }
        }
        if open.isEmpty && done.isEmpty { lines = "No tasks scheduled." }

        let ctx = cal.isDateInToday(selectedDate) ? "Today" : "On \(dateString)"
        return """
        You are a concise productivity assistant. Respond in English in max 3 sentences, direct and without filler phrases. No markdown.

        \(ctx) (\(dateString)):
        \(lines)
        """
    }
}

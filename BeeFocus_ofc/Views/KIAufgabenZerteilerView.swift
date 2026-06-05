import SwiftUI
import FoundationModels

struct KIAufgabenZerteilerView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("aiProvider")            private var aiProvider: String = "gemini"
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("openaiSelectedModel")   private var openaiModel: String = OpenAIService.models[0]
    @AppStorage("groqSelectedModel")     private var groqModel:   String = GroqService.models[0]

    @State private var aufgabenTitel: String = ""
    @State private var kontext: String = ""
    @State private var generatedText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showSetup = false
    @State private var keyInput = ""
    @State private var keyVisible = false
    @State private var subtasks: [SubtaskItem] = []
    @State private var taskAdded = false
    @State private var cardsAppeared = false
    @State private var subtasksAppeared = false
    @FocusState private var titleFocused: Bool

    private var isDark: Bool { colorScheme == .dark }
    private var accent: Color { aktivesThema.isEmpty ? Color(red: 0.3, green: 0.85, blue: 0.5) : appThemaFarben(aktivesThema).0 }
    private var accent2: Color { aktivesThema.isEmpty ? Color(red: 0.1, green: 0.65, blue: 0.4) : appThemaFarben(aktivesThema).1 }

    struct SubtaskItem: Identifiable {
        let id = UUID()
        var title: String
        var dauer: String
        var isSelected: Bool = true
    }

    private var hasKey: Bool {
        switch aiProvider {
        case "openai": return KeychainHelper.load(for: OpenAIService.keychainKey) != nil
        case "groq":   return KeychainHelper.load(for: GroqService.keychainKey) != nil
        default:       return KeychainHelper.load(for: GeminiService.keychainKey) != nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        headerCard
                            .opacity(cardsAppeared ? 1 : 0)
                            .offset(y: cardsAppeared ? 0 : -16)
                            .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.05), value: cardsAppeared)
                        inputCard
                        if showSetup { setupCard }
                        else if let error = errorMessage { errorCard(error) }
                        else if isLoading && generatedText.isEmpty { loadingCard }
                        else if !subtasks.isEmpty { subtasksCard }
                        Spacer(minLength: 32)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(String(localized: "ki_splitter_nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "ki_done")) { dismiss() } }
                ToolbarItem(placement: .principal) { providerMenu }
            }
        }
        .onAppear {
            titleFocused = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { cardsAppeared = true }
        }
    }

    private var providerMenu: some View {
        Menu {
            Picker("", selection: $aiProvider) {
                Label("Gemini",             systemImage: "sparkles").tag("gemini")
                Label("OpenAI",             systemImage: "brain").tag("openai")
                Label("Groq",               systemImage: "bolt.fill").tag("groq")
                Label("Apple Intelligence", systemImage: "apple.logo").tag("apple")
            }
        } label: {
            HStack(spacing: 4) {
                Text(providerLabel).font(.headline)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
            }
            .foregroundStyle(.primary)
        }
        .onChange(of: aiProvider) { _ in generatedText = ""; errorMessage = nil; showSetup = false; subtasks = [] }
    }

    // MARK: - Header
    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                Image(systemName: "scissors")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "ki_splitter_header"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                Text(String(localized: "ki_splitter_header_subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .themeGlass(cornerRadius: 16)
    }

    // MARK: - Input
    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "ki_splitter_input_task_label")).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            TextField(String(localized: "ki_splitter_input_task_placeholder"), text: $aufgabenTitel, axis: .vertical)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isDark ? .white : .primary)
                .lineLimit(1...3)
                .focused($titleFocused)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Text(String(localized: "ki_splitter_input_context_label")).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            TextField(String(localized: "ki_splitter_input_context_placeholder"), text: $kontext, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(isDark ? .white.opacity(0.85) : .primary)
                .lineLimit(2...4)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Button {
                guard !aufgabenTitel.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                subtasks = []; generatedText = ""; taskAdded = false
                Task { await generate() }
            } label: {
                HStack(spacing: 8) {
                    if isLoading { ProgressView().scaleEffect(0.85).tint(.white) }
                    else { Image(systemName: "scissors") }
                    Text(isLoading ? String(localized: "ki_splitter_btn_analyzing") : String(localized: "ki_splitter_btn_split"))
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 13)
                        .fill(aufgabenTitel.trimmingCharacters(in: .whitespaces).isEmpty
                              ? AnyShapeStyle(Color.secondary.opacity(0.3))
                              : AnyShapeStyle(LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)))
                )
            }
            .buttonStyle(.plain)
            .disabled(aufgabenTitel.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
        }
        .padding(16)
        .themeGlass(cornerRadius: 16)
    }

    // MARK: - States
    private var loadingCard: some View {
        HStack(spacing: 10) {
            ProgressView().tint(accent)
            Text(String(localized: "ki_splitter_loading")).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .themeGlass(cornerRadius: 16)
    }

    private var subtasksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 12)).foregroundStyle(accent)
                    Text(String(format: String(localized: "ki_splitter_result_count"), subtasks.count))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isDark ? .white : .primary)
                }
                Spacer()
                Button {
                    addAsOneTask()
                } label: {
                    Label(taskAdded ? String(localized: "ki_splitter_added") : String(localized: "ki_splitter_save"),
                          systemImage: taskAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(taskAdded ? Color.green : accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(taskAdded)
                .animation(.spring(response: 0.3), value: taskAdded)
            }

            Divider().opacity(0.3)

            // Vorschau: Hauptaufgabe
            VStack(alignment: .leading, spacing: 4) {
                Label(aufgabenTitel, systemImage: "checkmark.square")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                if !kontext.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(kontext)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            // Teilaufgaben-Liste
            ForEach(Array(subtasks.enumerated()), id: \.element.id) { i, task in
                subtaskRow(task: task, index: i)
            }
        }
        .padding(16)
        .themeGlass(cornerRadius: 16)
        .onAppear {
            subtasksAppeared = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { subtasksAppeared = true }
        }
    }

    @ViewBuilder
    private func subtaskRow(task: SubtaskItem, index: Int) -> some View {
        let delay = 0.05 + Double(index) * 0.055
        HStack(spacing: 10) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isDark ? .white.opacity(0.85) : .primary)
                if !task.dauer.isEmpty {
                    Text("⏱ \(task.dauer)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(subtasksAppeared ? 1 : 0)
        .offset(x: subtasksAppeared ? 0 : -20)
        .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(delay), value: subtasksAppeared)
    }

    private func addAsOneTask() {
        let subTaskList = subtasks.map { SubTask(title: $0.title) }
        let todo = TodoItem(
            title: aufgabenTitel.trimmingCharacters(in: .whitespaces),
            description: kontext.trimmingCharacters(in: .whitespaces),
            subTasks: subTaskList
        )
        todoStore.addTodo(todo)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation { taskAdded = true }
    }

    private func errorCard(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(String(localized: "ki_error_title")).font(.subheadline.weight(.semibold))
            }
            Text(msg).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button { errorMessage = nil; Task { await generate() } } label: {
                Label(hasKey ? String(localized: "ki_error_try_again") : String(localized: "ki_error_add_key"),
                      systemImage: hasKey ? "arrow.clockwise" : "key.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded { if !hasKey { showSetup = true } })
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .themeGlass(cornerRadius: 16)
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(aiProvider == "openai" ? String(localized: "ki_setup_openai_key") : aiProvider == "groq" ? String(localized: "ki_setup_groq_key") : String(localized: "ki_setup_gemini_key"))
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                Group {
                    if keyVisible { TextField(String(localized: "ki_api_key_placeholder"), text: $keyInput) }
                    else          { SecureField(String(localized: "ki_api_key_placeholder"), text: $keyInput) }
                }
                .font(.system(size: 14, design: .monospaced)).autocorrectionDisabled().textInputAutocapitalization(.never)
                Button { keyVisible.toggle() } label: {
                    Image(systemName: keyVisible ? "eye.slash" : "eye").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(10).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Button(String(localized: "ki_cancel")) { showSetup = false }
                    .font(.subheadline).foregroundStyle(.secondary).buttonStyle(.plain)
                Spacer()
                Button(String(localized: "ki_save")) {
                    let t = keyInput.trimmingCharacters(in: .whitespaces); guard !t.isEmpty else { return }
                    let k: String
                    switch aiProvider { case "openai": k = OpenAIService.keychainKey; case "groq": k = GroqService.keychainKey; default: k = GeminiService.keychainKey }
                    KeychainHelper.save(t, for: k); showSetup = false; Task { await generate() }
                }
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8).background(accent, in: Capsule()).buttonStyle(.plain)
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16).themeGlass(cornerRadius: 16)
    }

    // MARK: - Generation
    private func generate() async {
        isLoading = true; errorMessage = nil; generatedText = ""; subtasks = []
        let prompt = buildPrompt()
        var raw = ""
        switch aiProvider {
        case "apple":
            if #available(iOS 26.0, *) {
                if case .available = SystemLanguageModel.default.availability {
                    do { let s = LanguageModelSession(); for try await p in s.streamResponse(to: prompt) { raw = p.content }; generatedText = raw }
                    catch { errorMessage = error.localizedDescription; isLoading = false; return }
                } else { errorMessage = String(localized: "ki_apple_not_available"); isLoading = false; return }
            } else { errorMessage = String(localized: "ki_apple_requires_ios26"); isLoading = false; return }
        case "openai":
            if let k = KeychainHelper.load(for: OpenAIService.keychainKey), !k.isEmpty {
                do { for try await c in OpenAIService.stream(prompt: prompt, apiKey: k, model: openaiModel) { raw += c; generatedText = raw } }
                catch { if raw.isEmpty { errorMessage = error.localizedDescription; isLoading = false; return } }
            } else { showSetup = true; isLoading = false; return }
        case "groq":
            if let k = KeychainHelper.load(for: GroqService.keychainKey), !k.isEmpty {
                do { for try await c in GroqService.stream(prompt: prompt, apiKey: k, model: groqModel) { raw += c; generatedText = raw } }
                catch { if raw.isEmpty { errorMessage = error.localizedDescription; isLoading = false; return } }
            } else { showSetup = true; isLoading = false; return }
        default:
            if let k = KeychainHelper.load(for: GeminiService.keychainKey), !k.isEmpty {
                do { for try await c in GeminiService.stream(prompt: prompt, apiKey: k) { raw += c; generatedText = raw } }
                catch { if raw.isEmpty { errorMessage = error.localizedDescription; isLoading = false; return } }
            } else { showSetup = true; isLoading = false; return }
        }
        isLoading = false
        parseSubtasks(from: raw)
    }

    private var promptLanguage: String {
        let code = Locale.current.languageCode ?? "en"
        return Locale(identifier: "en").localizedString(forLanguageCode: code) ?? "English"
    }

    private func buildPrompt() -> String {
        let kontextZeile = kontext.trimmingCharacters(in: .whitespaces).isEmpty ? "" : "\nContext: \(kontext)"
        return """
        Break down this task into concrete, actionable subtasks. Respond ONLY with a JSON array, no other text.

        Task: \(aufgabenTitel)\(kontextZeile)

        Format: [{"title":"Subtask","dauer":"e.g. 30min or 2h"},...]

        Rules:
        - 5–10 subtasks, logically ordered
        - Each subtask is independently executable and clearly formulated
        - Time estimate should be realistic
        - In \(promptLanguage)
        """
    }

    private func parseSubtasks(from raw: String) {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            // Fallback: extract lines starting with - or numbers
            let lines = raw.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && ($0.hasPrefix("-") || $0.first?.isNumber == true) }
                .map { $0.replacingOccurrences(of: "^[-•\\d\\.\\s]+", with: "", options: .regularExpression) }
                .filter { !$0.isEmpty }
            subtasks = lines.map { SubtaskItem(title: $0, dauer: "") }
            return
        }
        subtasks = arr.compactMap { d in
            guard let title = d["title"], !title.isEmpty else { return nil }
            return SubtaskItem(title: title, dauer: d["dauer"] ?? "")
        }
    }

    private var providerLabel: String {
        switch aiProvider { case "openai": return "OpenAI"; case "groq": return "Groq"; case "apple": return "Apple"; default: return "Gemini" }
    }
}

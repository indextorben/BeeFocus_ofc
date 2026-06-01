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
    @State private var addedIDs: Set<UUID> = []
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
            .navigationTitle("KI-Aufgaben-Zerteiler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .principal) { providerMenu }
            }
        }
        .onAppear { titleFocused = true }
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
                Text("Aufgaben-Zerteiler")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                Text("KI zerlegt komplexe Aufgaben in konkrete Schritte")
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
            Text("Aufgabe").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            TextField("z.B. Website redesign, Buch schreiben, Präsentation…", text: $aufgabenTitel, axis: .vertical)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isDark ? .white : .primary)
                .lineLimit(1...3)
                .focused($titleFocused)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Text("Kontext (optional)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            TextField("Deadline, Tools, Ziel, Besonderheiten…", text: $kontext, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(isDark ? .white.opacity(0.85) : .primary)
                .lineLimit(2...4)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Button {
                guard !aufgabenTitel.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                subtasks = []; generatedText = ""
                Task { await generate() }
            } label: {
                HStack(spacing: 8) {
                    if isLoading { ProgressView().scaleEffect(0.85).tint(.white) }
                    else { Image(systemName: "scissors") }
                    Text(isLoading ? "Analysiere…" : "In Teilaufgaben zerlegen")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(
                    aufgabenTitel.trimmingCharacters(in: .whitespaces).isEmpty
                    ? Color.secondary.opacity(0.3)
                    : LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 13)
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
            Text("KI zerlegt deine Aufgabe…").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .themeGlass(cornerRadius: 16)
    }

    private var subtasksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 12)).foregroundStyle(accent)
                    Text("\(subtasks.count) Teilaufgaben erkannt")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isDark ? .white : .primary)
                }
                Spacer()
                Button {
                    let toAdd = subtasks.filter { $0.isSelected && !addedIDs.contains($0.id) }
                    toAdd.forEach { s in
                        var todo = TodoItem(title: s.title)
                        todoStore.addTodo(todo)
                        addedIDs.insert(s.id)
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("Alle hinzufügen", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(subtasks.filter { $0.isSelected && !addedIDs.contains($0.id) }.isEmpty)
            }

            ForEach($subtasks) { $task in
                subtaskRow($task)
            }
        }
        .padding(16)
        .themeGlass(cornerRadius: 16)
    }

    private func subtaskRow(_ task: Binding<SubtaskItem>) -> some View {
        let isAdded = addedIDs.contains(task.wrappedValue.id)
        return HStack(spacing: 12) {
            Button {
                if !isAdded { task.wrappedValue.isSelected.toggle() }
            } label: {
                Image(systemName: isAdded ? "checkmark.circle.fill" : (task.wrappedValue.isSelected ? "circle.fill" : "circle"))
                    .font(.system(size: 20))
                    .foregroundStyle(isAdded ? .green : (task.wrappedValue.isSelected ? accent : .secondary))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.wrappedValue.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isDark ? .white.opacity(isAdded ? 0.4 : 0.9) : .primary)
                    .strikethrough(isAdded)
                if !task.wrappedValue.dauer.isEmpty {
                    Text("⏱ \(task.wrappedValue.dauer)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !isAdded {
                Button {
                    var todo = TodoItem(title: task.wrappedValue.title)
                    todoStore.addTodo(todo)
                    addedIDs.insert(task.wrappedValue.id)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .opacity(isAdded ? 0.6 : 1)
    }

    private func errorCard(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("KI nicht verfügbar").font(.subheadline.weight(.semibold))
            }
            Text(msg).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button { errorMessage = nil; Task { await generate() } } label: {
                Label(hasKey ? "Erneut versuchen" : "API-Key hinzufügen",
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
            Text(aiProvider == "openai" ? "OpenAI API Key" : aiProvider == "groq" ? "Groq API Key" : "Gemini API Key")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                Group {
                    if keyVisible { TextField("API Key…", text: $keyInput) }
                    else          { SecureField("API Key…", text: $keyInput) }
                }
                .font(.system(size: 14, design: .monospaced)).autocorrectionDisabled().textInputAutocapitalization(.never)
                Button { keyVisible.toggle() } label: {
                    Image(systemName: keyVisible ? "eye.slash" : "eye").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(10).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Button("Abbrechen") { showSetup = false }
                    .font(.subheadline).foregroundStyle(.secondary).buttonStyle(.plain)
                Spacer()
                Button("Speichern") {
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
                } else { errorMessage = "Apple Intelligence ist nicht verfügbar."; isLoading = false; return }
            } else { errorMessage = "Apple Intelligence benötigt iOS 26."; isLoading = false; return }
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

    private func buildPrompt() -> String {
        let kontextZeile = kontext.trimmingCharacters(in: .whitespaces).isEmpty ? "" : "\nKontext: \(kontext)"
        return """
        Zerlege diese Aufgabe in konkrete, umsetzbare Teilaufgaben. Antworte NUR mit einem JSON-Array, kein anderer Text.

        Aufgabe: \(aufgabenTitel)\(kontextZeile)

        Format: [{"title":"Teilaufgabe","dauer":"z.B. 30min oder 2h"},...]

        Regeln:
        - 5–10 Teilaufgaben, logisch geordnet
        - Jede Teilaufgabe ist alleine ausführbar und klar formuliert
        - Zeitschätzung realistisch
        - Auf Deutsch
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

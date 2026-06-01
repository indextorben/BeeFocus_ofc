import SwiftUI
import FoundationModels

struct KIAufgabenAnalyseView: View {
    let todos: [TodoItem]

    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("aiProvider")           private var aiProvider: String = "gemini"
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("openaiSelectedModel")  private var openaiModel: String = OpenAIService.models[0]
    @AppStorage("groqSelectedModel")    private var groqModel:   String = GroqService.models[0]

    @State private var generatedText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showSetup = false
    @State private var keyInput = ""
    @State private var keyVisible = false
    @State private var showGuide = false

    private var isDark: Bool { colorScheme == .dark }
    private var accent: Color { aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : appThemaFarben(aktivesThema).0 }
    private var accent2: Color { aktivesThema.isEmpty ? Color(red: 0.35, green: 0.2, blue: 1.0) : appThemaFarben(aktivesThema).1 }

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
                        statsOverview
                        if showSetup { setupCard }
                        else { contentArea }
                        Spacer(minLength: 32)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("KI-Aufgaben-Analyse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Menu {
                        Picker("", selection: $aiProvider) {
                            Label("Gemini",             systemImage: "sparkles").tag("gemini")
                            Label("OpenAI",             systemImage: "brain").tag("openai")
                            Label("Groq",               systemImage: "bolt.fill").tag("groq")
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
                        generatedText = ""; errorMessage = nil; showSetup = false
                    }
                }
            }
            .sheet(isPresented: $showGuide) {
                NavigationStack {
                    GeminiKeyGuideView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Fertig") {
                                    showGuide = false
                                    if hasKey { Task { await generate() } }
                                }
                            }
                        }
                }
            }
        }
        .task { await generate() }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Aufgaben-Analyse")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                Text("\(providerLabel) analysiert deine \(todos.count) Aufgaben")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !isLoading && generatedText.isEmpty && errorMessage == nil && !showSetup {
                Button { Task { await generate() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .themeGlass(cornerRadius: 16)
    }

    // MARK: - Stats Overview

    private var statsOverview: some View {
        let open     = todos.filter { !$0.isCompleted }.count
        let overdue  = todos.filter { !$0.isCompleted && ($0.dueDate.map { $0 < Date() } == true) }.count
        let high     = todos.filter { !$0.isCompleted && $0.priority == .high }.count
        let noDate   = todos.filter { !$0.isCompleted && $0.dueDate == nil }.count

        return HStack(spacing: 8) {
            analyseChip("\(open)", "Offen",         color: accent)
            analyseChip("\(overdue)", "Überfällig", color: .red)
            analyseChip("\(high)", "Dringend",      color: .orange)
            analyseChip("\(noDate)", "Ohne Datum",  color: .secondary)
        }
    }

    private func analyseChip(_ value: String, _ label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Content

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
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ProgressView().tint(accent)
                Text("Analysiere deine Aufgaben…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Die KI prüft Prioritäten, Deadlines und Muster in deiner Aufgabenliste.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .themeGlass(cornerRadius: 16)
    }

    private var responseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                Text("KI-Analyse")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if !isLoading {
                    Button { Task { await generate() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(generatedText)
                .font(.body)
                .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)
                .multilineTextAlignment(.leading)
                .animation(.easeIn(duration: 0.1), value: generatedText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isLoading {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(accent)
                            .frame(width: 5, height: 5)
                            .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.18), value: isLoading)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .themeGlass(cornerRadius: 16)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("KI nicht verfügbar").font(.subheadline.weight(.semibold))
            }
            Text(message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if hasKey {
                    Button {
                        errorMessage = nil; Task { await generate() }
                    } label: {
                        Label("Erneut versuchen", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { showSetup = true; errorMessage = nil } label: {
                        Label("API-Key hinzufügen", systemImage: "key.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .themeGlass(cornerRadius: 16)
    }

    // MARK: - Setup Card

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(aiProvider == "openai" ? "OpenAI API Key" : aiProvider == "groq" ? "Groq API Key" : "Gemini API Key")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isDark ? .white : .primary)

            HStack(spacing: 8) {
                Group {
                    if keyVisible { TextField("API Key…", text: $keyInput) }
                    else          { SecureField("API Key…", text: $keyInput) }
                }
                .font(.system(size: 14, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                Button { keyVisible.toggle() } label: {
                    Image(systemName: keyVisible ? "eye.slash" : "eye").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

            HStack {
                Button("Abbrechen") { showSetup = false }
                    .font(.subheadline).foregroundStyle(.secondary).buttonStyle(.plain)
                Spacer()
                Button("Speichern & Analysieren") {
                    let trimmed = keyInput.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let kcKey: String
                    switch aiProvider {
                    case "openai": kcKey = OpenAIService.keychainKey
                    case "groq":   kcKey = GroqService.keychainKey
                    default:       kcKey = GeminiService.keychainKey
                    }
                    KeychainHelper.save(trimmed, for: kcKey)
                    showSetup = false
                    Task { await generate() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(accent, in: Capsule())
                .buttonStyle(.plain)
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .themeGlass(cornerRadius: 16)
    }

    // MARK: - Generation

    private func generate() async {
        isLoading = true
        errorMessage = nil
        generatedText = ""

        let prompt = buildPrompt()

        switch aiProvider {
        case "apple":
            if #available(iOS 26.0, *) {
                if case .available = SystemLanguageModel.default.availability {
                    do {
                        let session = LanguageModelSession()
                        let stream = session.streamResponse(to: prompt)
                        for try await partial in stream { generatedText = partial.content }
                        isLoading = false; return
                    } catch { errorMessage = error.localizedDescription }
                } else { errorMessage = "Apple Intelligence ist auf diesem Gerät nicht verfügbar." }
            } else { errorMessage = "Apple Intelligence benötigt iOS 26." }

        case "openai":
            if let key = KeychainHelper.load(for: OpenAIService.keychainKey), !key.isEmpty {
                do {
                    let stream = OpenAIService.stream(prompt: prompt, apiKey: key, model: openaiModel)
                    for try await chunk in stream { generatedText += chunk }
                    isLoading = false; return
                } catch { if generatedText.isEmpty { errorMessage = error.localizedDescription } }
            } else { showSetup = true }

        case "groq":
            if let key = KeychainHelper.load(for: GroqService.keychainKey), !key.isEmpty {
                do {
                    let stream = GroqService.stream(prompt: prompt, apiKey: key, model: groqModel)
                    for try await chunk in stream { generatedText += chunk }
                    isLoading = false; return
                } catch { if generatedText.isEmpty { errorMessage = error.localizedDescription } }
            } else { showSetup = true }

        default:
            if let key = KeychainHelper.load(for: GeminiService.keychainKey), !key.isEmpty {
                do {
                    let stream = GeminiService.stream(prompt: prompt, apiKey: key)
                    for try await chunk in stream { generatedText += chunk }
                    isLoading = false; return
                } catch { if generatedText.isEmpty { errorMessage = error.localizedDescription } }
            } else { showSetup = true }
        }

        isLoading = false
    }

    private func buildPrompt() -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let open     = todos.filter { !$0.isCompleted }
        let overdue  = open.filter { $0.dueDate.map { $0 < today } == true }
        let todayDue = open.filter { $0.dueDate.map { cal.isDateInToday($0) } == true }
        let highPrio = open.filter { $0.priority == .high }
        let noDate   = open.filter { $0.dueDate == nil }

        var taskLines = open.prefix(25).map { t -> String in
            var line = "- \(t.title)"
            if let due = t.dueDate {
                let overdueMark = due < today ? " [ÜBERFÄLLIG]" : ""
                let f = DateFormatter(); f.dateFormat = "dd.MM."; f.locale = Locale(identifier: "de_DE")
                line += " (fällig: \(f.string(from: due))\(overdueMark))"
            }
            switch t.priority {
            case .high:   line += " [Hoch]"
            case .medium: line += " [Mittel]"
            case .low:    break
            }
            return line
        }.joined(separator: "\n")

        return """
        Du bist ein produktiver Assistent. Analysiere diese Aufgabenliste und gib auf Deutsch eine strukturierte, ehrliche Analyse.

        AUFGABEN (\(open.count) offen):
        \(taskLines)

        STATISTIK:
        - Überfällig: \(overdue.count)
        - Heute fällig: \(todayDue.count)
        - Hohe Priorität: \(highPrio.count)
        - Ohne Datum: \(noDate.count)

        Analysiere:
        1. **Kritische Engpässe** – was muss sofort erledigt werden und warum
        2. **Priorisierungsempfehlung** – Top 3 Aufgaben für heute mit Begründung
        3. **Muster & Risiken** – was fällt auf (z.B. viele überfällige, fehlende Deadlines)
        4. **Konkrete Tipp** – ein umsetzbarer Tipp für bessere Aufgabenverwaltung

        Sei direkt, konkret und hilfreich. Maximal 280 Wörter. Nutze Emojis sparsam.
        """
    }

    private var providerLabel: String {
        switch aiProvider {
        case "openai": return "OpenAI"
        case "groq":   return "Groq"
        case "apple":  return "Apple"
        default:       return "Gemini"
        }
    }
}

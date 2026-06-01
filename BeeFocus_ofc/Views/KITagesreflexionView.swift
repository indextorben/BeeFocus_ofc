import SwiftUI
import FoundationModels

struct KITagesreflexionView: View {
    let todos: [TodoItem]

    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("aiProvider")            private var aiProvider: String = "gemini"
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("openaiSelectedModel")   private var openaiModel: String = OpenAIService.models[0]
    @AppStorage("groqSelectedModel")     private var groqModel:   String = GroqService.models[0]
    @AppStorage("dailyFocusGoalMinutes") private var dailyGoal: Int = 60

    @State private var generatedText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showSetup = false
    @State private var keyInput = ""
    @State private var keyVisible = false
    @State private var showGuide = false

    private var isDark: Bool { colorScheme == .dark }
    private var accent: Color { aktivesThema.isEmpty ? Color(red: 1.0, green: 0.5, blue: 0.8) : appThemaFarben(aktivesThema).0 }
    private var accent2: Color { aktivesThema.isEmpty ? Color(red: 0.7, green: 0.3, blue: 1.0) : appThemaFarben(aktivesThema).1 }

    private var hasKey: Bool {
        switch aiProvider {
        case "openai": return KeychainHelper.load(for: OpenAIService.keychainKey) != nil
        case "groq":   return KeychainHelper.load(for: GroqService.keychainKey) != nil
        default:       return KeychainHelper.load(for: GeminiService.keychainKey) != nil
        }
    }

    // Computed stats for today
    private var todayStats: (completed: Int, focusMins: Int, mood: Int?, streak: Int) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let completed = todos.filter {
            $0.isCompleted && ($0.completedAt.map { cal.isDate($0, inSameDayAs: today) } == true)
        }.count
        let focusMins = todoStore.dailyFocusMinutes[today] ?? 0
        let mood = StimmungsStore.shared.heutigerEintrag?.stufe
        // Streak: consecutive days with focus
        var streak = 0
        var day = today
        while true {
            let m = todoStore.dailyFocusMinutes[day] ?? 0
            if m == 0 { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return (completed, focusMins, mood, streak)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Softer evening gradient
                ThemeBackgroundView().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        headerCard
                        dayAtGlance
                        if showSetup { setupCard }
                        else { contentArea }
                        Spacer(minLength: 32)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("KI-Tagesreflexion")
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
                            Text(providerLabel).font(.headline)
                            Image(systemName: "chevron.down").font(.caption.weight(.semibold))
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
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Tagesreflexion")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                let f: DateFormatter = { let d = DateFormatter(); d.locale = Locale(identifier: "de_DE"); d.dateFormat = "EEEE, d. MMMM"; return d }()
                Text(f.string(from: Date()))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
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
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Day at a Glance

    private var dayAtGlance: some View {
        let stats = todayStats
        return HStack(spacing: 8) {
            reflexionChip("✅", "\(stats.completed)", "Erledigt", color: Color(red: 0.3, green: 0.85, blue: 0.5))
            reflexionChip("⏱", formatMins(stats.focusMins), "Fokus", color: Color(red: 0.3, green: 0.6, blue: 1.0))
            if let mood = stats.mood {
                reflexionChip(stimmungsEmoji(mood), stimmungsLabel(mood), "Stimmung", color: stimmungsColor(mood))
            }
            reflexionChip("🔥", "\(stats.streak)d", "Streak", color: .orange)
        }
    }

    private func reflexionChip(_ icon: String, _ value: String, _ label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 18))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
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
                Text("Die KI reflektiert deinen Tag…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Text("Einen Moment – deine persönliche Reflexion wird erstellt.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
    }

    private var responseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                Text("Deine Reflexion")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .textCase(.uppercase)
                Spacer()
                if !isLoading {
                    Button { Task { await generate() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(generatedText)
                .font(.body)
                .foregroundStyle(.white.opacity(0.88))
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

            if !isLoading {
                Divider().opacity(0.15)
                Button {
                    UIPasteboard.general.string = generatedText
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label("Reflexion kopieren", systemImage: "doc.on.doc")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.25), lineWidth: 1))
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("KI nicht verfügbar").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            }
            Text(message).font(.caption).foregroundStyle(.white.opacity(0.5)).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if hasKey {
                    Button { errorMessage = nil; Task { await generate() } } label: {
                        Label("Erneut versuchen", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { showSetup = true; errorMessage = nil } label: {
                        Label("API-Key hinzufügen", systemImage: "key.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.orange.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Setup Card

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(aiProvider == "openai" ? "OpenAI API Key" : aiProvider == "groq" ? "Groq API Key" : "Gemini API Key")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)

            HStack(spacing: 8) {
                Group {
                    if keyVisible { TextField("API Key…", text: $keyInput) }
                    else          { SecureField("API Key…", text: $keyInput) }
                }
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.white)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                Button { keyVisible.toggle() } label: {
                    Image(systemName: keyVisible ? "eye.slash" : "eye").foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            HStack {
                Button("Abbrechen") { showSetup = false }
                    .font(.subheadline).foregroundStyle(.white.opacity(0.4)).buttonStyle(.plain)
                Spacer()
                Button("Speichern") {
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
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(accent, in: Capsule()).buttonStyle(.plain)
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
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
        let stats = todayStats

        let completedTitles = todos
            .filter { $0.isCompleted && ($0.completedAt.map { cal.isDate($0, inSameDayAs: today) } == true) }
            .prefix(10)
            .map { "- \($0.title)" }
            .joined(separator: "\n")

        let openTitles = todos
            .filter { !$0.isCompleted && ($0.dueDate.map { cal.isDate($0, inSameDayAs: today) } == true) }
            .prefix(8)
            .map { "- \($0.title)" }
            .joined(separator: "\n")

        let moodLine = stats.mood.map { "Stimmung: \(stimmungsLabel($0)) (\(stimmungsEmoji($0)))" } ?? "Stimmung: nicht erfasst"
        let focusGoalPct = dailyGoal > 0 ? Int(Double(stats.focusMins) / Double(dailyGoal) * 100) : 0
        let f: DateFormatter = { let d = DateFormatter(); d.locale = Locale(identifier: "de_DE"); d.dateFormat = "EEEE, d. MMMM"; return d }()

        return """
        Du bist ein einfühlsamer Produktivitäts-Coach. Schreibe auf Deutsch eine persönliche, warme Tagesreflexion.

        HEUTIGER TAG: \(f.string(from: Date()))

        ERGEBNISSE:
        - Erledigte Aufgaben: \(stats.completed)
        \(completedTitles.isEmpty ? "" : completedTitles + "\n")
        - Offene heutige Aufgaben: \(openTitles.isEmpty ? "keine" : "\n" + openTitles)
        - Fokuszeit: \(formatMins(stats.focusMins)) (Ziel: \(dailyGoal)min, \(focusGoalPct)% erreicht)
        - \(moodLine)
        - Streak: \(stats.streak) Tage in Folge

        Schreibe eine Reflexion mit 3 Teilen:
        1. **Rückblick** – Was war heute gut? Erkenne konkrete Leistungen an (bezogen auf die echten Daten).
        2. **Erkenntnisse** – Was kann man aus dem heutigen Tag lernen? (Ehrlich, nicht übertrieben positiv)
        3. **Ausblick** – Ein motivierender, konkreter Gedanke für morgen.

        Ton: warm, persönlich, direkt – wie ein guter Freund. Keine Floskeln. Maximal 200 Wörter. Nutze die echten Zahlen.
        """
    }

    private func formatMins(_ mins: Int) -> String {
        if mins < 60 { return "\(mins)min" }
        let h = mins / 60; let m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
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

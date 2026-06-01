import SwiftUI
import FoundationModels

struct KIFokusStrategieView: View {
    let todos: [TodoItem]

    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("aiProvider")            private var aiProvider: String = "gemini"
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("openaiSelectedModel")   private var openaiModel: String = OpenAIService.models[0]
    @AppStorage("groqSelectedModel")     private var groqModel:   String = GroqService.models[0]
    @AppStorage("dailyFocusGoalMinutes") private var dailyGoal: Int = 60
    @AppStorage("aktiverTimerModus")     private var aktiverTimerModus: String = ""

    @State private var generatedText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showSetup = false
    @State private var keyInput = ""
    @State private var keyVisible = false

    private var isDark: Bool { colorScheme == .dark }
    private var accent: Color { aktivesThema.isEmpty ? Color(red: 1.0, green: 0.55, blue: 0.1) : appThemaFarben(aktivesThema).0 }
    private var accent2: Color { aktivesThema.isEmpty ? Color(red: 0.9, green: 0.35, blue: 0.0) : appThemaFarben(aktivesThema).1 }

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
                LinearGradient(
                    colors: [Color(red: 0.10, green: 0.06, blue: 0.04),
                             Color(red: 0.18, green: 0.10, blue: 0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        headerCard
                        profileOverview
                        if showSetup { setupCard }
                        else if let error = errorMessage { errorCard(error) }
                        else if isLoading && generatedText.isEmpty { loadingCard }
                        else if !generatedText.isEmpty { responseCard }
                        Spacer(minLength: 32)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("KI-Fokus-Strategie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .principal) { providerMenu }
            }
        }
        .task { await generate() }
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
        .onChange(of: aiProvider) { _ in generatedText = ""; errorMessage = nil; showSetup = false }
    }

    // MARK: - Header
    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Fokus-Strategie")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Personalisierter KI-Produktivitätsplan für dich")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            if !isLoading {
                Button { Task { await generate() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Profile
    private var profileOverview: some View {
        let stats = computeStats()
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            profileChip("🎯", "\(dailyGoal)min", "Tagesziel",   color: accent)
            profileChip("⏱", formatMins(stats.avgFocusMins), "Ø/Tag 7d",  color: .cyan)
            profileChip("✅", "\(stats.rate)%",  "Abschlussrate", color: Color(red: 0.3, green: 0.85, blue: 0.5))
            profileChip("🔥", "\(stats.streak)d", "Streak",      color: .orange)
            profileChip("📋", "\(stats.open)",   "Offen",        color: .secondary)
            profileChip("⚡", aktiverTimerModus.isEmpty ? "Standard" : aktiverTimerModus, "Timer", color: .purple)
        }
    }

    private func profileChip(_ icon: String, _ value: String, _ label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(icon).font(.system(size: 16))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Content
    private var loadingCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ProgressView().tint(accent)
                Text("KI erstellt deine persönliche Strategie…")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.6))
            }
            Text("Analysiert Muster, Stärken und Verbesserungspotenzial.")
                .font(.caption).foregroundStyle(.white.opacity(0.35)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(20)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
    }

    private var responseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 12)).foregroundStyle(accent)
                Text("Deine Fokus-Strategie")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.45)).textCase(.uppercase)
                Spacer()
                if !isLoading {
                    Button {
                        UIPasteboard.general.string = generatedText
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "doc.on.doc").font(.system(size: 12)).foregroundStyle(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(generatedText)
                .font(.body).foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.leading)
                .animation(.easeIn(duration: 0.1), value: generatedText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isLoading {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().fill(accent).frame(width: 5, height: 5)
                            .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.18), value: isLoading)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.3), lineWidth: 1))
    }

    private func errorCard(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("KI nicht verfügbar").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            }
            Text(msg).font(.caption).foregroundStyle(.white.opacity(0.5)).fixedSize(horizontal: false, vertical: true)
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
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.orange.opacity(0.3), lineWidth: 1))
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(aiProvider == "openai" ? "OpenAI API Key" : aiProvider == "groq" ? "Groq API Key" : "Gemini API Key")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            HStack(spacing: 8) {
                Group {
                    if keyVisible { TextField("API Key…", text: $keyInput) }
                    else          { SecureField("API Key…", text: $keyInput) }
                }
                .font(.system(size: 14, design: .monospaced)).foregroundStyle(.white)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                Button { keyVisible.toggle() } label: {
                    Image(systemName: keyVisible ? "eye.slash" : "eye").foregroundStyle(.white.opacity(0.4))
                }.buttonStyle(.plain)
            }
            .padding(10).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Button("Abbrechen") { showSetup = false }
                    .font(.subheadline).foregroundStyle(.white.opacity(0.4)).buttonStyle(.plain)
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
        .padding(16).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Stats
    private func computeStats() -> (avgFocusMins: Int, rate: Int, streak: Int, open: Int) {
        let cal = Calendar.current
        let focusVals = (0..<7).compactMap { offset -> Int? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) else { return nil }
            return todoStore.dailyFocusMinutes[day]
        }
        let avg = focusVals.isEmpty ? 0 : focusVals.reduce(0, +) / focusVals.count
        let completed = todos.filter { $0.isCompleted }.count
        let total = todos.count
        let rate = total > 0 ? Int(Double(completed) / Double(total) * 100) : 0
        var streak = 0
        var day = cal.startOfDay(for: Date())
        while true {
            let m = todoStore.dailyFocusMinutes[day] ?? 0
            if m == 0 { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        let open = todos.filter { !$0.isCompleted }.count
        return (avg, rate, streak, open)
    }

    // MARK: - Generation
    private func generate() async {
        isLoading = true; errorMessage = nil; generatedText = ""
        let prompt = buildPrompt()
        switch aiProvider {
        case "apple":
            if #available(iOS 26.0, *) {
                if case .available = SystemLanguageModel.default.availability {
                    do { let s = LanguageModelSession(); for try await p in s.streamResponse(to: prompt) { generatedText = p.content }; isLoading = false; return }
                    catch { errorMessage = error.localizedDescription }
                } else { errorMessage = "Apple Intelligence ist nicht verfügbar." }
            } else { errorMessage = "Apple Intelligence benötigt iOS 26." }
        case "openai":
            if let k = KeychainHelper.load(for: OpenAIService.keychainKey), !k.isEmpty {
                do { for try await c in OpenAIService.stream(prompt: prompt, apiKey: k, model: openaiModel) { generatedText += c }; isLoading = false; return }
                catch { if generatedText.isEmpty { errorMessage = error.localizedDescription } }
            } else { showSetup = true }
        case "groq":
            if let k = KeychainHelper.load(for: GroqService.keychainKey), !k.isEmpty {
                do { for try await c in GroqService.stream(prompt: prompt, apiKey: k, model: groqModel) { generatedText += c }; isLoading = false; return }
                catch { if generatedText.isEmpty { errorMessage = error.localizedDescription } }
            } else { showSetup = true }
        default:
            if let k = KeychainHelper.load(for: GeminiService.keychainKey), !k.isEmpty {
                do { for try await c in GeminiService.stream(prompt: prompt, apiKey: k) { generatedText += c }; isLoading = false; return }
                catch { if generatedText.isEmpty { errorMessage = error.localizedDescription } }
            } else { showSetup = true }
        }
        isLoading = false
    }

    private func buildPrompt() -> String {
        let stats = computeStats()
        let cal = Calendar.current
        let dayFocus = (0..<7).compactMap { offset -> String? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) else { return nil }
            let mins = todoStore.dailyFocusMinutes[day] ?? 0
            let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "EEE"
            return "\(f.string(from: day)): \(mins)min"
        }.reversed().joined(separator: ", ")

        let moods = StimmungsStore.shared.last7Days()
            .compactMap { $0.stufe }
            .map { stimmungsLabel($0) }
            .joined(separator: ", ")

        let schlaf = SchlafStore.shared.schnittStunden7Tage
        let highPrio = todos.filter { !$0.isCompleted && $0.priority == .high }.count
        let overdue  = todos.filter { !$0.isCompleted && ($0.dueDate.map { $0 < Date() } == true) }.count

        return """
        Du bist ein Elite-Produktivitäts-Coach. Erstelle auf Deutsch eine personalisierte Fokus-Strategie.

        NUTZERPROFIL:
        - Fokuszeit letzte 7 Tage: \(dayFocus)
        - Durchschnitt: \(formatMins(stats.avgFocusMins))/Tag (Ziel: \(dailyGoal)min)
        - Abschlussrate: \(stats.rate)%
        - Aktueller Streak: \(stats.streak) Tage
        - Offene Aufgaben: \(stats.open) (davon \(highPrio) dringend, \(overdue) überfällig)
        - Timer-Modus: \(aktiverTimerModus.isEmpty ? "Standard Pomodoro 25/5" : aktiverTimerModus)
        - Stimmungsverlauf (7 Tage): \(moods.isEmpty ? "nicht erfasst" : moods)
        - Ø Schlaf: \(schlaf > 0 ? String(format: "%.1fh", schlaf) : "nicht erfasst")

        Erstelle eine Strategie mit 4 Abschnitten:
        1. **Dein Produktivitätsprofil** – Was zeigen die Daten über deinen Arbeitsstil? (Stärken & Schwächen)
        2. **Optimaler Fokus-Rhythmus** – Welcher Timer-Modus, welche Tageszeiten, wie lange Blöcke passen zu dir?
        3. **Diese Woche konkret** – 3 spezifische, umsetzbare Aktionen basierend auf deinen echten Zahlen
        4. **Langfristige Entwicklung** – Ein Ziel für die nächsten 30 Tage mit Messbarkeit

        Ton: direkt, ehrlich, motivierend. Nutze die echten Daten. Maximal 280 Wörter.
        """
    }

    private func formatMins(_ mins: Int) -> String {
        if mins == 0 { return "0min" }
        if mins < 60 { return "\(mins)min" }
        let h = mins / 60; let m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }

    private var providerLabel: String {
        switch aiProvider { case "openai": return "OpenAI"; case "groq": return "Groq"; case "apple": return "Apple"; default: return "Gemini" }
    }
}

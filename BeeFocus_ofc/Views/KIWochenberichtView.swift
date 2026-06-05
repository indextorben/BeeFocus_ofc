import SwiftUI
import FoundationModels

struct KIWochenberichtView: View {
    let todos: [TodoItem]

    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("aiProvider")            private var aiProvider: String = "gemini"
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("openaiSelectedModel")   private var openaiModel: String = OpenAIService.models[0]
    @AppStorage("groqSelectedModel")     private var groqModel:   String = GroqService.models[0]

    @State private var generatedText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showSetup = false
    @State private var keyInput = ""
    @State private var keyVisible = false

    private var isDark: Bool { colorScheme == .dark }
    private var accent: Color { aktivesThema.isEmpty ? Color(red: 0.2, green: 0.75, blue: 1.0) : appThemaFarben(aktivesThema).0 }
    private var accent2: Color { aktivesThema.isEmpty ? Color(red: 0.1, green: 0.5, blue: 0.9) : appThemaFarben(aktivesThema).1 }

    private var hasKey: Bool {
        switch aiProvider {
        case "openai": return KeychainHelper.load(for: OpenAIService.keychainKey) != nil
        case "groq":   return KeychainHelper.load(for: GroqService.keychainKey) != nil
        default:       return KeychainHelper.load(for: GeminiService.keychainKey) != nil
        }
    }

    // MARK: - Week stats
    private var weekStats: (completed: Int, focusMins: Int, avgMood: Double?, bestDay: String) {
        let cal = Calendar.current
        var totalCompleted = 0
        var totalFocus = 0
        var moods: [Int] = []
        var bestFocus = 0
        var bestDayLabel = ""

        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) else { continue }
            let done = todos.filter { $0.isCompleted && ($0.completedAt.map { cal.isDate($0, inSameDayAs: day) } == true) }.count
            let focus = todoStore.dailyFocusMinutes[day] ?? 0
            totalCompleted += done
            totalFocus += focus
            if focus > bestFocus { bestFocus = focus; bestDayLabel = weekdayDE(day) }
            if let mood = StimmungsStore.shared.eintraege.first(where: { cal.isDate($0.date, inSameDayAs: day) })?.stufe {
                moods.append(mood)
            }
        }

        let avg = moods.isEmpty ? nil : Double(moods.reduce(0, +)) / Double(moods.count)
        return (totalCompleted, totalFocus, avg, bestDayLabel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        headerCard
                        weekOverview
                        if showSetup { setupCard }
                        else { contentArea }
                        Spacer(minLength: 32)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(String(localized: "ki_weekly_nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
        }
        .task { await generate() }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "ki_done")) { dismiss() }
        }
        ToolbarItem(placement: .principal) {
            providerMenu
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
        .onChange(of: aiProvider) { _ in generatedText = ""; errorMessage = nil; showSetup = false }
    }

    // MARK: - Header
    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "ki_weekly_header"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(weekRangeLabel)
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

    // MARK: - Week Overview
    private var weekOverview: some View {
        let stats = weekStats
        return HStack(spacing: 8) {
            weekChip("✅", "\(stats.completed)", String(localized: "ki_weekly_stat_completed"), color: Color(red: 0.3, green: 0.85, blue: 0.5))
            weekChip("⏱", formatMins(stats.focusMins), String(localized: "ki_weekly_stat_focus"), color: accent)
            if let avg = stats.avgMood {
                weekChip(stimmungsEmoji(Int(avg.rounded())), String(format: "%.1f", avg), String(localized: "ki_weekly_stat_mood"), color: stimmungsColor(Int(avg.rounded())))
            }
            if !stats.bestDay.isEmpty {
                weekChip("🏆", stats.bestDay, String(localized: "ki_weekly_stat_best_day"), color: .orange)
            }
        }
    }

    private func weekChip(_ icon: String, _ value: String, _ label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(icon).font(.system(size: 16))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Content
    @ViewBuilder private var contentArea: some View {
        if let error = errorMessage { errorCard(error) }
        else if isLoading && generatedText.isEmpty { loadingCard }
        else if !generatedText.isEmpty { responseCard }
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ProgressView().tint(accent)
                Text(String(localized: "ki_weekly_loading")).font(.subheadline).foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity).padding(20)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
    }

    private var responseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 12, weight: .semibold)).foregroundStyle(accent)
                Text(String(localized: "ki_weekly_result_title"))
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
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.25), lineWidth: 1))
    }

    private func errorCard(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(String(localized: "ki_error_title")).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            }
            Text(msg).font(.caption).foregroundStyle(.white.opacity(0.5)).fixedSize(horizontal: false, vertical: true)
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
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.orange.opacity(0.3), lineWidth: 1))
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(aiProvider == "openai" ? String(localized: "ki_setup_openai_key") : aiProvider == "groq" ? String(localized: "ki_setup_groq_key") : String(localized: "ki_setup_gemini_key"))
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            HStack(spacing: 8) {
                Group {
                    if keyVisible { TextField(String(localized: "ki_api_key_placeholder"), text: $keyInput) }
                    else          { SecureField(String(localized: "ki_api_key_placeholder"), text: $keyInput) }
                }
                .font(.system(size: 14, design: .monospaced)).foregroundStyle(.white)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                Button { keyVisible.toggle() } label: {
                    Image(systemName: keyVisible ? "eye.slash" : "eye").foregroundStyle(.white.opacity(0.4))
                }.buttonStyle(.plain)
            }
            .padding(10).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Button(String(localized: "ki_cancel")) { showSetup = false }
                    .font(.subheadline).foregroundStyle(.white.opacity(0.4)).buttonStyle(.plain)
                Spacer()
                Button(String(localized: "ki_save")) {
                    let t = keyInput.trimmingCharacters(in: .whitespaces); guard !t.isEmpty else { return }
                    let k: String
                    switch aiProvider { case "openai": k = OpenAIService.keychainKey; case "groq": k = GroqService.keychainKey; default: k = GeminiService.keychainKey }
                    KeychainHelper.save(t, for: k); showSetup = false; Task { await generate() }
                }
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(accent, in: Capsule()).buttonStyle(.plain)
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
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
                } else { errorMessage = String(localized: "ki_apple_not_available") }
            } else { errorMessage = String(localized: "ki_apple_requires_ios26") }
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

    private var promptLanguage: String {
        let code = Locale.current.languageCode ?? "en"
        return Locale(identifier: "en").localizedString(forLanguageCode: code) ?? "English"
    }

    private func buildPrompt() -> String {
        let cal = Calendar.current
        var dayLines: [String] = []
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) else { continue }
            let done  = todos.filter { $0.isCompleted && ($0.completedAt.map { cal.isDate($0, inSameDayAs: day) } == true) }.count
            let focus = todoStore.dailyFocusMinutes[day] ?? 0
            let mood  = StimmungsStore.shared.eintraege.first(where: { cal.isDate($0.date, inSameDayAs: day) }).map { stimmungsLabel($0.stufe) } ?? "-"
            dayLines.append("• \(weekdayDE(day)): \(done) tasks completed, \(focus)min focus, mood: \(mood)")
        }
        let stats = weekStats
        return """
        You are a productivity analyst. Write a structured weekly report in \(promptLanguage).

        WEEKLY DATA (last 7 days):
        \(dayLines.reversed().joined(separator: "\n"))

        SUMMARY:
        - Total completed: \(stats.completed) tasks
        - Total focus time: \(formatMins(stats.focusMins))
        - Best day: \(stats.bestDay.isEmpty ? "–" : stats.bestDay)
        - Average mood: \(stats.avgMood.map { String(format: "%.1f/5", $0) } ?? "not tracked")

        Write a weekly report with 4 sections:
        1. **Weekly performance** – What was achieved? How was the focus time distributed?
        2. **Highs & lows** – Which days were strong/weak and why probably?
        3. **Patterns** – Do you see trends (e.g. focus drops on certain days, mood-productivity correlation)?
        4. **Recommendation for next week** – 2-3 concrete, actionable measures.

        Tone: professional, direct, constructive. Maximum 250 words. Reference the real numbers.
        """
    }

    private var weekRangeLabel: String {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -6, to: Date()) else { return "" }
        let f = DateFormatter(); f.locale = Locale.current; f.dateFormat = "MMM d"
        return "\(f.string(from: start)) – \(f.string(from: Date()))"
    }

    private func weekdayDE(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale.current; f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private func formatMins(_ mins: Int) -> String {
        if mins < 60 { return "\(mins)m" }
        let h = mins / 60; let m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }

    private var providerLabel: String {
        switch aiProvider { case "openai": return "OpenAI"; case "groq": return "Groq"; case "apple": return "Apple"; default: return "Gemini" }
    }
}

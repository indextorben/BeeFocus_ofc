import SwiftUI
import UIKit
import FoundationModels

struct KIGesamtberichtView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("aiProvider")             private var aiProvider: String = "gemini"
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("openaiSelectedModel")   private var openaiModel: String = OpenAIService.models[0]
    @AppStorage("groqSelectedModel")     private var groqModel:   String = GroqService.models[0]

    // Section toggles
    @State private var inclAufgaben    = true
    @State private var inclFokuszeit   = true
    @State private var inclGewohnheiten = true
    @State private var inclJournal     = true
    @State private var inclWasser      = true
    @State private var inclAbzeichen   = true

    @State private var generatedText: String = ""
    @State private var isLoading        = false
    @State private var errorMessage: String? = nil
    @State private var showSetup        = false
    @State private var keyInput         = ""
    @State private var keyVisible       = false
    @State private var exportImage: UIImage? = nil
    @State private var showExportSheet  = false

    private var accent:  Color { aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : appThemaFarben(aktivesThema).0 }
    private var accent2: Color { aktivesThema.isEmpty ? Color(red: 0.35, green: 0.2,  blue: 1.0) : appThemaFarben(aktivesThema).1 }

    private var hasKey: Bool {
        switch aiProvider {
        case "openai": return KeychainHelper.load(for: OpenAIService.keychainKey) != nil
        case "groq":   return KeychainHelper.load(for: GroqService.keychainKey)   != nil
        default:       return KeychainHelper.load(for: GeminiService.keychainKey) != nil
        }
    }

    // Quick stats
    private var completedCount: Int { todoStore.todos.filter { $0.isCompleted }.count }
    private var totalFocusMins: Int { todoStore.dailyFocusMinutes.values.reduce(0, +) }
    private var habitCount:     Int { HabitStore.shared.habits.count }
    private var journalCount:   Int { JournalStore.shared.entries.count }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        headerCard
                        sectionPicker
                        if showSetup { setupCard }
                        else if isLoading && generatedText.isEmpty { loadingCard }
                        if !generatedText.isEmpty { reportCard }
                        if let err = errorMessage { errorCard(err) }
                        Spacer(minLength: 40)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("AI Overall Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .principal) { providerMenu }
                if !generatedText.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button { exportReport() } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let img = exportImage {
                    GesamtberichtShareSheet(items: [img])
                }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 52, height: 52)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI Overall Report")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text("All app data analyzed & summarized")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
            }

            HStack(spacing: 8) {
                quickStat("✅", "\(completedCount)", "Completed")
                quickStat("⏱", "\(totalFocusMins)m", "Focus")
                quickStat("🔥", "\(habitCount)", "Habits")
                quickStat("📖", "\(journalCount)", "Journal")
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(accent.opacity(0.2), lineWidth: 1))
    }

    private func quickStat(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(emoji).font(.system(size: 16))
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What should be included?")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .textCase(.uppercase)
                .tracking(0.8)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                toggle("checkmark.circle.fill", "Tasks",        Color(red: 0.3,  green: 0.8,  blue: 0.5),  $inclAufgaben)
                toggle("timer",                "Focus time",   Color(red: 0.3,  green: 0.6,  blue: 1.0),  $inclFokuszeit)
                toggle("calendar.badge.checkmark", "Habits",   Color(red: 0.3, green: 0.82, blue: 0.5), $inclGewohnheiten)
                toggle("book.closed.fill",     "Journal",      Color(red: 0.65, green: 0.35, blue: 1.0),  $inclJournal)
                toggle("drop.fill",            "Water",        Color(red: 0.15, green: 0.75, blue: 0.95), $inclWasser)
                toggle("medal.fill",           "Badges",       Color(red: 0.6,  green: 0.3,  blue: 0.9),  $inclAbzeichen)
            }

            Button { Task { await generate() } } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView().tint(.white).scaleEffect(0.9)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(generatedText.isEmpty ? "Generate report" : "Regenerate")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .opacity(isLoading ? 0.7 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private func toggle(_ icon: String, _ label: String, _ color: Color, _ binding: Binding<Bool>) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { binding.wrappedValue.toggle() } } label: {
            HStack(spacing: 10) {
                Image(systemName: binding.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(binding.wrappedValue ? color : .white.opacity(0.2))
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(color.opacity(binding.wrappedValue ? 1 : 0.3))
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(binding.wrappedValue ? .white : .white.opacity(0.35))
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(binding.wrappedValue ? color.opacity(0.12) : .white.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(binding.wrappedValue ? color.opacity(0.25) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading

    private var loadingCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(accent.opacity(0.15), lineWidth: 3).frame(width: 72, height: 72)
                Image(systemName: "sparkles")
                    .font(.system(size: 30))
                    .foregroundStyle(accent)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            }
            VStack(spacing: 6) {
                Text("AI is analyzing all your data…")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                Text("This may take a moment")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(44)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Report Card

    private var reportCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(accent)
                        Text("AI OVERALL REPORT")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.4)).tracking(1.5)
                    }
                    Text(formattedDate).font(.system(size: 13)).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                if isLoading {
                    ProgressView().tint(accent).scaleEffect(0.8)
                } else {
                    Button {
                        UIPasteboard.general.string = generatedText
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "doc.on.doc").font(.system(size: 14)).foregroundStyle(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }

            Rectangle().fill(.white.opacity(0.1)).frame(height: 1)

            ForEach(parsedSections, id: \.title) { section in
                reportSection(section)
            }

            if isLoading {
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().fill(accent).frame(width: 5, height: 5)
                            .animation(.easeInOut(duration: 0.45).repeatForever().delay(Double(i) * 0.15), value: isLoading)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(accent.opacity(0.2), lineWidth: 1))
    }

    private func reportSection(_ section: BerichtSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(section.color.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: section.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(section.color)
                }
                Text(section.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(section.body)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .animation(.easeIn(duration: 0.1), value: section.body)
        }
        .padding(14)
        .background(section.color.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(section.color.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Error & Setup

    private func errorCard(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("AI unavailable").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            }
            Text(msg).font(.caption).foregroundStyle(.white.opacity(0.5)).fixedSize(horizontal: false, vertical: true)
            Button {
                errorMessage = nil
                if hasKey { Task { await generate() } } else { showSetup = true }
            } label: {
                Label(hasKey ? "Try again" : "Add API Key",
                      systemImage: hasKey ? "arrow.clockwise" : "key.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
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
                Button("Cancel") { showSetup = false }
                    .font(.subheadline).foregroundStyle(.white.opacity(0.4)).buttonStyle(.plain)
                Spacer()
                Button("Save") {
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

    // MARK: - Provider Menu

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

    private var providerLabel: String {
        switch aiProvider {
        case "openai": return "OpenAI"
        case "groq":   return "Groq"
        case "apple":  return "Apple"
        default:       return "Gemini"
        }
    }

    // MARK: - Section Parsing

    struct BerichtSection {
        let title: String
        let body: String
        let icon: String
        let color: Color
    }

    private let sectionMeta: [(keyword: String, icon: String, color: Color)] = [
        ("Overall Assessment", "sparkles",                  Color(red: 0.55, green: 0.35, blue: 1.0)),
        ("Tasks",              "checkmark.circle.fill",     Color(red: 0.3,  green: 0.8,  blue: 0.5)),
        ("Focus Time",         "timer",                     Color(red: 0.3,  green: 0.6,  blue: 1.0)),
        ("Focus",              "timer",                     Color(red: 0.3,  green: 0.6,  blue: 1.0)),
        ("Habits",             "calendar.badge.checkmark",  Color(red: 0.3,  green: 0.82, blue: 0.5)),
        ("Journal",            "book.closed.fill",          Color(red: 0.65, green: 0.35, blue: 1.0)),
        ("Water",              "drop.fill",                 Color(red: 0.15, green: 0.75, blue: 0.95)),
        ("Badges",             "medal.fill",                Color(red: 0.6,  green: 0.3,  blue: 0.9)),
        ("Recommendations",    "lightbulb.fill",            Color(red: 1.0,  green: 0.7,  blue: 0.2)),
        ("Improvement",        "lightbulb.fill",            Color(red: 1.0,  green: 0.7,  blue: 0.2)),
    ]

    private var parsedSections: [BerichtSection] {
        let lines = generatedText.components(separatedBy: "\n")
        var sections: [BerichtSection] = []
        var currentTitle = ""
        var currentLines: [String] = []

        func flush() {
            guard !currentTitle.isEmpty else { return }
            let body = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return }
            let meta = sectionMeta.first(where: { currentTitle.lowercased().contains($0.keyword.lowercased()) })
            sections.append(BerichtSection(
                title: currentTitle,
                body: body,
                icon: meta?.icon ?? "doc.text.fill",
                color: meta?.color ?? Color(red: 0.55, green: 0.35, blue: 1.0)
            ))
        }

        for line in lines {
            if line.hasPrefix("## ") {
                flush()
                currentTitle = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                currentLines = []
            } else if !line.hasPrefix("# ") {
                let clean = line
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "*", with: "")
                currentLines.append(clean)
            }
        }
        flush()

        if sections.isEmpty && !generatedText.isEmpty {
            return [BerichtSection(title: "AI Analysis", body: generatedText, icon: "sparkles",
                                   color: Color(red: 0.55, green: 0.35, blue: 1.0))]
        }
        return sections
    }

    // MARK: - Export

    @MainActor
    private func exportReport() {
        let exportView = BerichtExportView(
            sections: parsedSections,
            completedCount: completedCount,
            totalFocusMins: totalFocusMins,
            habitCount: habitCount,
            journalCount: journalCount,
            date: formattedDate,
            accent: accent,
            accent2: accent2
        )
        let renderer = ImageRenderer(content: exportView.frame(width: 390))
        renderer.scale = 3.0
        if let img = renderer.uiImage {
            exportImage = img
            showExportSheet = true
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let f = DateFormatter(); f.locale = Locale.current; f.dateFormat = "d. MMMM yyyy"
        return f.string(from: Date())
    }

    // MARK: - AI Generation

    private func generate() async {
        isLoading = true; errorMessage = nil; generatedText = ""
        let prompt = buildPrompt()

        switch aiProvider {
        case "apple":
            if #available(iOS 26.0, *) {
                if case .available = SystemLanguageModel.default.availability {
                    do {
                        let s = LanguageModelSession()
                        for try await p in s.streamResponse(to: prompt) { generatedText = p.content }
                        isLoading = false; return
                    } catch { errorMessage = error.localizedDescription }
                } else { errorMessage = "Apple Intelligence is not available on this device." }
            } else { errorMessage = "Apple Intelligence requires iOS 26." }
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
        var parts: [String] = ["""
        Create a professional, personal and motivating AI overall report for a BeeFocus user.
        Respond exclusively in English.
        Structure the report with ## headings. ALWAYS begin with ## Overall Assessment.
        Write concretely, constructively positive and address the user directly (you-form).
        Avoid Markdown except ## headings. No asterisks, no bullet lists.
        """]

        if inclAufgaben {
            let total = todoStore.todos.count
            let done  = todoStore.todos.filter { $0.isCompleted }.count
            let open  = total - done
            let overdue = todoStore.todos.filter { !$0.isCompleted && ($0.dueDate.map { $0 < Date() } == true) }.count
            let favorites = todoStore.todos.filter { $0.isFavorite }.count
            let cats = Dictionary(grouping: todoStore.todos, by: { $0.category?.name ?? "No Category" })
            let catStr = cats.map { "\($0.key): \($0.value.count)" }.joined(separator: ", ")
            parts.append("## Tasks\nTotal: \(total) | Completed: \(done) | Open: \(open) | Overdue: \(overdue) | Favorites: \(favorites). Categories: \(catStr)")
        }

        if inclFokuszeit {
            let total = todoStore.dailyFocusMinutes.values.reduce(0, +)
            let days  = todoStore.dailyFocusMinutes.count
            let avg   = days > 0 ? total / days : 0
            let today = todoStore.dailyFocusMinutes[Calendar.current.startOfDay(for: Date())] ?? 0
            parts.append("## Focus Time\nTotal: \(total) minutes | Avg per day: \(avg) min | Today: \(today) min | Active days: \(days)")
        }

        if inclGewohnheiten {
            let habits = HabitStore.shared.habits
            if habits.isEmpty {
                parts.append("## Habits\nNo habits tracked yet.")
            } else {
                let str = habits.map { "\($0.name) – Streak: \($0.currentStreak) days, total: \($0.totalCompletions)×" }.joined(separator: "; ")
                parts.append("## Habits\n\(str)")
            }
        }

        if inclJournal {
            let entries = JournalStore.shared.entries
            if entries.isEmpty {
                parts.append("## Journal\nNo journal entries yet.")
            } else {
                let avgMood   = Double(entries.map { $0.moodScore   }.reduce(0, +)) / Double(entries.count)
                let avgEnergy = Double(entries.map { $0.energyScore }.reduce(0, +)) / Double(entries.count)
                parts.append("## Journal\nEntries: \(entries.count) | Avg mood: \(String(format: "%.1f", avgMood))/5 | Avg energy: \(String(format: "%.1f", avgEnergy))/5")
            }
        }

        if inclWasser {
            let today = WasserStore.shared.todayTotal
            let goal  = WasserStore.shared.tagesziel
            let pct   = goal > 0 ? Int(Double(today) / Double(goal) * 100) : 0
            parts.append("## Water\nToday: \(today) ml of \(goal) ml goal (\(pct)%)")
        }

        if inclAbzeichen {
            let earned = FokusModeManager.shared.unlockedAchievementIDs.count
            let total  = FokusAchievement.all.count
            parts.append("## Badges\nUnlocked: \(earned) of \(total) possible badges")
        }

        parts.append("Finally, write a ## Recommendations section with exactly 3 concrete, actionable tips based on the data above.")

        return parts.joined(separator: "\n\n")
    }
}

// MARK: - Export View (rendered to image)

struct BerichtExportView: View {
    let sections: [KIGesamtberichtView.BerichtSection]
    let completedCount: Int
    let totalFocusMins: Int
    let habitCount: Int
    let journalCount: Int
    let date: String
    let accent: Color
    let accent2: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header gradient band
            LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("BeeFocus")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Text(date)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Text("AI Overall Report")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))

                        HStack(spacing: 10) {
                            exportChip("✅ \(completedCount)", "Completed")
                            exportChip("⏱ \(totalFocusMins)m", "Focus")
                            exportChip("🔥 \(habitCount)", "Habits")
                            exportChip("📖 \(journalCount)", "Journal")
                        }
                    }
                    .padding(20)
                }
                .frame(height: 150)

            // Sections on light background
            VStack(alignment: .leading, spacing: 10) {
                ForEach(sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: section.icon)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(section.color)
                            Text(section.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.15))
                        }
                        Text(section.body)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(red: 0.25, green: 0.25, blue: 0.3))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(section.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }

                HStack {
                    Spacer()
                    Text("Created with BeeFocus · AI Analysis · \(date)")
                        .font(.system(size: 10))
                        .foregroundStyle(.gray.opacity(0.45))
                }
                .padding(.top, 6)
            }
            .padding(16)
            .background(Color(red: 0.96, green: 0.96, blue: 0.98))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 6)
        .padding(16)
        .background(Color(red: 0.93, green: 0.93, blue: 0.96))
    }

    private func exportChip(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Share Sheet

struct GesamtberichtShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

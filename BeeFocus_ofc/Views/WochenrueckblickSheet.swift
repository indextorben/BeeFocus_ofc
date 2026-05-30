import SwiftUI

struct WochenrueckblickSheet: View {

    let todoStore: TodoStore
    let themeC1: Color
    let themeC2: Color

    @Environment(\.dismiss)            private var dismiss
    @AppStorage("aiProvider")          private var aiProvider: String = "gemini"
    @AppStorage("geminiSelectedModel") private var geminiModel: String = GeminiService.models[0]
    @AppStorage("openaiSelectedModel") private var openaiModel: String = OpenAIService.models[0]
    @AppStorage("groqSelectedModel")   private var groqModel:   String = GroqService.models[0]
    @AppStorage("darkModeEnabled")     private var darkModeEnabled = false

    @State private var reviewText: String = ""
    @State private var isGenerating = false
    @State private var generated = false

    // MARK: - Week data

    private var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2  // Monday
        return c
    }

    private var thisWeekDays: [Date] { weekDays(offsetWeeks: 0) }
    private var lastWeekDays: [Date] { weekDays(offsetWeeks: -1) }

    private func weekDays(offsetWeeks: Int) -> [Date] {
        let today = cal.startOfDay(for: Date())
        guard let monday = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let start = cal.date(byAdding: .weekOfYear, value: offsetWeeks, to: monday) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func completedCount(days: [Date]) -> Int {
        days.reduce(0) { $0 + (todoStore.dailyStats[$1] ?? 0) }
    }

    private func focusMinutes(days: [Date]) -> Int {
        days.reduce(0) { $0 + (todoStore.dailyFocusMinutes[$1] ?? 0) }
    }

    private var thisWeekCompleted: Int { completedCount(days: thisWeekDays) }
    private var lastWeekCompleted: Int { completedCount(days: lastWeekDays) }
    private var thisWeekFocus:     Int { focusMinutes(days: thisWeekDays) }
    private var lastWeekFocus:     Int { focusMinutes(days: lastWeekDays) }

    private var bestDayThisWeek: (day: Date, count: Int)? {
        thisWeekDays
            .map { ($0, todoStore.dailyStats[$0] ?? 0) }
            .max { $0.1 < $1.1 }
            .flatMap { $0.1 > 0 ? $0 : nil }
    }

    private var completedTodosThisWeek: [TodoItem] {
        let startOfWeek = thisWeekDays.first ?? Date()
        let endOfWeek   = cal.date(byAdding: .day, value: 1, to: thisWeekDays.last ?? Date()) ?? Date()
        return todoStore.todos.filter {
            guard let at = $0.completedAt else { return false }
            return at >= startOfWeek && at < endOfWeek
        }
    }

    private var taskDiff: Int  { thisWeekCompleted - lastWeekCompleted }
    private var focusDiff: Int { thisWeekFocus - lastWeekFocus }

    // MARK: - Body

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                handle

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerSection
                        statsGrid
                        dayBarsSection
                        if generated {
                            aiReviewCard
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity))
                        } else {
                            generateButton
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Handle

    private var handle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.secondary.opacity(0.4))
            .frame(width: 36, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [themeC1, themeC2],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(String(localized: "review_title"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(darkModeEnabled ? .white : .primary)
            }
            Text(weekRangeLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var weekRangeLabel: String {
        guard let first = thisWeekDays.first, let last = thisWeekDays.last else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateFormat = "d. MMM"
        return "\(fmt.string(from: first)) – \(fmt.string(from: last))"
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "checkmark.circle.fill",
                color: themeC1,
                value: "\(thisWeekCompleted)",
                label: String(localized: "review_tasks_done"),
                diff: taskDiff
            )
            statCard(
                icon: "timer",
                color: themeC2,
                value: focusTimeLabel(thisWeekFocus),
                label: String(localized: "review_focus_time"),
                diff: focusDiff
            )
        }
    }

    private func focusTimeLabel(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func statCard(icon: String, color: Color, value: String, label: String, diff: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if diff != 0 {
                    diffBadge(diff)
                }
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(darkModeEnabled ? .white : .primary)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(c1: themeC1, c2: themeC2, dark: darkModeEnabled)
    }

    private func diffBadge(_ diff: Int) -> some View {
        let positive = diff > 0
        let label = positive ? "+\(diff)" : "\(diff)"
        let color: Color = positive ? .green : .red
        return Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }

    // MARK: - Day Bars

    private var dayBarsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "review_daily_tasks"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .bottom, spacing: 6) {
                let maxVal = max(1, (thisWeekDays + lastWeekDays)
                    .map { todoStore.dailyStats[$0] ?? 0 }.max() ?? 1)

                ForEach(Array(thisWeekDays.enumerated()), id: \.offset) { i, day in
                    let thisVal = todoStore.dailyStats[day] ?? 0
                    let lastVal = todoStore.dailyStats[lastWeekDays[safe: i] ?? day] ?? 0
                    let isToday = cal.isDateInToday(day)

                    VStack(spacing: 4) {
                        // bars
                        HStack(alignment: .bottom, spacing: 2) {
                            // last week (faint)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 10, height: max(4, CGFloat(lastVal) / CGFloat(maxVal) * 60))

                            // this week
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(colors: [themeC1, themeC2],
                                                     startPoint: .top, endPoint: .bottom))
                                .frame(width: 10, height: max(4, CGFloat(thisVal) / CGFloat(maxVal) * 60))
                        }

                        // day label
                        Text(shortWeekdayLabel(day))
                            .font(.system(size: 10, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? themeC1 : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 88)

            // Legend
            HStack(spacing: 16) {
                legendDot(color: Color.secondary.opacity(0.4), label: String(localized: "review_last_week"))
                legendDot(color: themeC1, label: String(localized: "review_this_week"))
            }
        }
        .padding(16)
        .glassCard(c1: themeC1, c2: themeC2, dark: darkModeEnabled)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 6)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func shortWeekdayLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateFormat = "E"
        return String(fmt.string(from: date).prefix(2))
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            Task { await generateReview() }
        } label: {
            HStack(spacing: 10) {
                if isGenerating {
                    ProgressView().scaleEffect(0.85).tint(.white)
                    Text(String(localized: "review_generating"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                    Text(String(localized: "review_generate_btn"))
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isGenerating
                    ? AnyShapeStyle(Color.secondary.opacity(0.4))
                    : AnyShapeStyle(LinearGradient(colors: [themeC1, themeC2],
                                                    startPoint: .leading, endPoint: .trailing)),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
    }

    // MARK: - AI Review Card

    private var aiReviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeC1)
                Text(String(localized: "review_ai_label"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    withAnimation { generated = false; reviewText = "" }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(reviewText)
                .font(.system(size: 15))
                .foregroundStyle(darkModeEnabled ? .white.opacity(0.9) : .primary)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeIn(duration: 0.05), value: reviewText)

            Button { dismiss() } label: {
                Text(String(localized: "review_close"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeC1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(themeC1.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .glassCard(c1: themeC1, c2: themeC2, dark: darkModeEnabled)
    }

    // MARK: - AI Generation

    private func generateReview() async {
        isGenerating = true

        let isEN = Locale.current.language.languageCode?.identifier == "en"
        let lang  = isEN ? "English" : "German"

        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateFormat = "EEEE"

        let dayLines = thisWeekDays.enumerated().map { i, day in
            let tasks = todoStore.dailyStats[day] ?? 0
            let focus = todoStore.dailyFocusMinutes[day] ?? 0
            let dayName = fmt.string(from: day)
            let last = todoStore.dailyStats[lastWeekDays[safe: i] ?? day] ?? 0
            return "\(dayName): \(tasks) tasks done, \(focus) min focus (last week: \(last) tasks)"
        }.joined(separator: "\n")

        let completedNames = completedTodosThisWeek.prefix(10).map { "• \($0.title)" }.joined(separator: "\n")

        let bestLine: String
        if let best = bestDayThisWeek {
            bestLine = "Best day: \(fmt.string(from: best.day)) with \(best.count) tasks"
        } else {
            bestLine = "No tasks completed this week"
        }

        let prompt = """
        You are a motivating productivity coach writing a weekly review. Be warm, personal, and encouraging but honest.

        Weekly stats:
        \(dayLines)

        Total this week: \(thisWeekCompleted) tasks done, \(thisWeekFocus) min focus
        Total last week: \(lastWeekCompleted) tasks done, \(lastWeekFocus) min focus
        \(bestLine)

        Completed tasks this week:
        \(completedNames.isEmpty ? "None recorded" : completedNames)

        Write a personal weekly review in \(lang) of 3-4 sentences. Mention specific numbers. Be encouraging about improvements, honest about slow days. End with one actionable tip for next week. Do NOT use bullet points or headers – flowing text only.
        """

        do {
            let stream = aiStream(prompt: prompt)
            for try await chunk in stream {
                await MainActor.run { reviewText += chunk }
            }
            await MainActor.run {
                isGenerating = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { generated = true }
            }
        } catch {
            await MainActor.run {
                reviewText = error.localizedDescription
                isGenerating = false
                withAnimation { generated = true }
            }
        }
    }

    private func aiStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        switch aiProvider {
        case "openai":
            let key = KeychainHelper.load(for: OpenAIService.keychainKey) ?? ""
            return OpenAIService.stream(prompt: prompt, apiKey: key, model: openaiModel)
        case "groq":
            let key = KeychainHelper.load(for: GroqService.keychainKey) ?? ""
            return GroqService.stream(prompt: prompt, apiKey: key, model: groqModel)
        default:
            let key = KeychainHelper.load(for: GeminiService.keychainKey) ?? ""
            return GeminiService.stream(prompt: prompt, apiKey: key)
        }
    }

    // MARK: - Background

    private var background: some View {
        darkModeEnabled
            ? Color(red: 0.07, green: 0.07, blue: 0.10)
            : Color(red: 0.94, green: 0.94, blue: 0.97)
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension View {
    func glassCard(c1: Color, c2: Color, dark: Bool) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [c1.opacity(dark ? 0.14 : 0.09),
                                                   c2.opacity(dark ? 0.07 : 0.05)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [c1.opacity(dark ? 0.40 : 0.25),
                                                 c2.opacity(dark ? 0.18 : 0.12)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(dark ? 0.25 : 0.07), radius: 16, x: 0, y: 6)
    }
}

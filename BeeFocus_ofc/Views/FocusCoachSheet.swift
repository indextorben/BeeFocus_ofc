import SwiftUI

struct FocusCoachSheet: View {

    let minutesWorked: Int
    let todos: [TodoItem]
    let themeC1: Color
    let themeC2: Color

    @Environment(\.dismiss) private var dismiss
    @AppStorage("aiProvider")          private var aiProvider: String = "gemini"
    @AppStorage("geminiSelectedModel") private var geminiModel: String = GeminiService.models[0]
    @AppStorage("openaiSelectedModel") private var openaiModel: String = OpenAIService.models[0]
    @AppStorage("groqSelectedModel")   private var groqModel:   String = GroqService.models[0]
    @AppStorage("darkModeEnabled")     private var darkModeEnabled = false

    @State private var phase: Phase = .loading
    @State private var recommendation: Recommendation? = nil
    @State private var errorText: String = ""

    enum Phase { case loading, ready, error }

    struct Recommendation {
        let taskTitle: String
        let reason: String
        let todo: TodoItem?
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                handle

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        completionHeader
                        contentArea
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .task { await loadRecommendation() }
    }

    // MARK: - Header

    private var handle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.secondary.opacity(0.4))
            .frame(width: 36, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }

    private var completionHeader: some View {
        VStack(spacing: 16) {
            // Celebration ring
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(LinearGradient(colors: [themeC1.opacity(0.15 - Double(i) * 0.04),
                                                       themeC2.opacity(0.08 - Double(i) * 0.02)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: CGFloat(72 + i * 20), height: CGFloat(72 + i * 20))
                }
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [themeC1, themeC2],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            VStack(spacing: 6) {
                Text(String(localized: "coach_session_done"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(darkModeEnabled ? .white : .primary)

                Text(minutesWorked > 0
                     ? String(format: String(localized: "coach_minutes_worked"), minutesWorked)
                     : String(localized: "coach_session_complete"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        switch phase {
        case .loading:
            loadingCard

        case .ready:
            if let rec = recommendation {
                recommendationCard(rec)
            }

        case .error:
            errorCard
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ProgressView()
                    .scaleEffect(0.9)
                    .tint(themeC1)
                Text(String(localized: "coach_analyzing"))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard(c1: themeC1, c2: themeC2, dark: darkModeEnabled)
    }

    private func recommendationCard(_ rec: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Label
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeC1)
                Text(String(localized: "coach_next_task_label"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            // Task title
            Text(rec.taskTitle)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(darkModeEnabled ? .white : .primary)
                .fixedSize(horizontal: false, vertical: true)

            // Reason
            Text(rec.reason)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Priority + due date if todo found
            if let todo = rec.todo {
                HStack(spacing: 8) {
                    priorityBadge(todo.priority)
                    if let due = todo.dueDate {
                        Label(due.formatted(date: .abbreviated, time: .omitted),
                              systemImage: "calendar")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }

            Divider()

            // Dismiss
            Button {
                dismiss()
            } label: {
                Text(String(localized: "coach_got_it"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [themeC1, themeC2],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .glassCard(c1: themeC1, c2: themeC2, dark: darkModeEnabled)
        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity))
    }

    private var errorCard: some View {
        VStack(spacing: 12) {
            Text(String(localized: "coach_no_suggestion"))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "Fertig")) { dismiss() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeC1)
        }
        .padding(20)
        .glassCard(c1: themeC1, c2: themeC2, dark: darkModeEnabled)
    }

    // MARK: - AI Call

    private func loadRecommendation() async {
        let openTodos = todos
            .filter { !$0.isCompleted }
            .sorted {
                let aPri = $0.priority == .high ? 0 : $0.priority == .medium ? 1 : 2
                let bPri = $1.priority == .high ? 0 : $1.priority == .medium ? 1 : 2
                if aPri != bPri { return aPri < bPri }
                if let a = $0.dueDate, let b = $1.dueDate { return a < b }
                return $0.dueDate != nil
            }
            .prefix(8)

        guard !openTodos.isEmpty else {
            await MainActor.run {
                recommendation = Recommendation(
                    taskTitle: String(localized: "coach_all_done_title"),
                    reason: String(localized: "coach_all_done_reason"),
                    todo: nil
                )
                withAnimation { phase = .ready }
            }
            return
        }

        let isEN = Locale.current.language.languageCode?.identifier == "en"
        let lang  = isEN ? "English" : "German"

        let taskList = openTodos.enumerated().map { i, t in
            var line = "\(i + 1). \(t.title) (priority: \(t.priority == .high ? "high" : t.priority == .medium ? "medium" : "low")"
            if let d = t.dueDate { line += ", due: \(d.formatted(date: .abbreviated, time: .omitted))" }
            line += ")"
            return line
        }.joined(separator: "\n")

        let today = Date().formatted(date: .complete, time: .omitted)

        let prompt = """
        You are a productivity coach. Today is \(today). The user just finished a \(minutesWorked)-minute focus session. Help them decide what to work on next.

        Open tasks:
        \(taskList)

        Choose the single best next task considering priority, due dates and what makes sense after a focus session. Respond ONLY in \(lang) and ONLY with this JSON (no markdown, no extra text):
        {"taskTitle":"exact title from the list","reason":"1-2 sentences why this task now"}
        """

        var raw = ""
        do {
            let stream = aiStream(prompt: prompt)
            for try await chunk in stream { raw += chunk }
            let rec = try parseRecommendation(raw: raw, todos: Array(openTodos))
            await MainActor.run {
                recommendation = rec
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { phase = .ready }
            }
        } catch {
            await MainActor.run {
                withAnimation { phase = .error }
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

    private func parseRecommendation(raw: String, todos: [TodoItem]) throws -> Recommendation {
        guard let start = raw.range(of: "{"), let end = raw.range(of: "}", options: .backwards) else {
            throw CoachError.noJSON
        }
        let jsonStr = String(raw[start.lowerBound...end.upperBound])
        guard let data = jsonStr.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title  = obj["taskTitle"] as? String,
              let reason = obj["reason"] as? String else {
            throw CoachError.parse
        }
        let matched = todos.first {
            $0.title.localizedCaseInsensitiveContains(title) ||
            title.localizedCaseInsensitiveContains($0.title)
        }
        return Recommendation(taskTitle: matched?.title ?? title, reason: reason, todo: matched)
    }

    // MARK: - Helpers

    private func priorityBadge(_ priority: TodoPriority) -> some View {
        let (label, color): (String, Color) = switch priority {
        case .high:   (String(localized: "priority_high"),   .red)
        case .medium: (String(localized: "priority_medium"), .orange)
        case .low:    (String(localized: "priority_low"),    .green)
        }
        return Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var background: some View {
        darkModeEnabled
            ? Color(red: 0.07, green: 0.07, blue: 0.10)
            : Color(red: 0.94, green: 0.94, blue: 0.97)
    }

    enum CoachError: Error { case noJSON, parse }
}

// MARK: - Glass card modifier

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

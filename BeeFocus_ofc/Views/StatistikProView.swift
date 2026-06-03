import SwiftUI
import FoundationModels

struct StatistikProView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var todoStore: TodoStore
    @ObservedObject private var sub = SubscriptionManager.shared

    @AppStorage("aiProvider")           private var aiProvider: String = "gemini"
    @AppStorage("openaiSelectedModel")  private var openaiModel: String = OpenAIService.models[0]
    @AppStorage("groqSelectedModel")    private var groqModel: String = GroqService.models[0]

    @State private var insightText = ""
    @State private var isGeneratingInsight = false
    @State private var showAIKeyAlert = false
    @State private var insightTask: Task<Void, Never>? = nil

    private var completedTodos: [TodoItem] {
        todoStore.todos.filter { $0.isCompleted && $0.completedAt != nil }
    }

    // MARK: - Computed stats

    private var weekdayData: [(label: String, value: Int)] {
        let cal = Calendar.current
        let df = DateFormatter()
        df.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "de")
        let symbols = df.shortWeekdaySymbols ?? []
        let order = [2, 3, 4, 5, 6, 7, 1]
        let grouped = Dictionary(grouping: completedTodos) { cal.component(.weekday, from: $0.completedAt!) }
        return order.map { day in
            let idx = (day - 1 + 7) % 7
            let label = symbols.indices.contains(idx) ? String(symbols[idx].prefix(2)) : "?"
            return (label: label, value: grouped[day]?.count ?? 0)
        }
    }

    private var timeData: [(label: String, value: Int)] {
        let cal = Calendar.current
        let buckets: [(String, (Int) -> Bool)] = [
            ("5–9", { (5..<10).contains($0) }),
            ("10–11", { (10..<12).contains($0) }),
            ("12–13", { (12..<14).contains($0) }),
            ("14–17", { (14..<18).contains($0) }),
            ("18–21", { (18..<22).contains($0) }),
            ("22–4", { $0 >= 22 || $0 < 5 })
        ]
        return buckets.map { (label, check) in
            let count = completedTodos.filter { check(cal.component(.hour, from: $0.completedAt!)) }.count
            return (label: label, value: count)
        }
    }

    private var categoryData: [(name: String, color: Color, rate: Double, done: Int, total: Int)] {
        todoStore.categories.compactMap { cat in
            let all = todoStore.todos.filter { $0.category?.id == cat.id }
            guard !all.isEmpty else { return nil }
            let done = all.filter { $0.isCompleted }.count
            return (
                name: cat.name,
                color: Color(hex: cat.colorHex),
                rate: Double(done) / Double(all.count),
                done: done,
                total: all.count
            )
        }
        .sorted { $0.rate > $1.rate }
    }

    private var priorityData: [(label: String, color: Color, rate: Double)] {
        let priorities: [(TodoPriority, String, Color)] = [
            (.high, "Hoch", .red),
            (.medium, "Mittel", .orange),
            (.low, "Niedrig", .green)
        ]
        return priorities.compactMap { (prio, label, color) in
            let all = todoStore.todos.filter { $0.priority == prio }
            guard !all.isEmpty else { return nil }
            let done = all.filter { $0.isCompleted }.count
            return (label: label, color: color, rate: Double(done) / Double(all.count))
        }
    }

    private var bestWeekday: String {
        weekdayData.max(by: { $0.value < $1.value })?.label ?? "–"
    }

    private var bestTimeBlock: String {
        timeData.max(by: { $0.value < $1.value })?.label ?? "–"
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    summaryRow
                    weekdayCard
                    timeCard
                    if !categoryData.isEmpty { categoryCard }
                    if !priorityData.isEmpty { priorityCard }
                    insightCard
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .navigationTitle("Pro Statistiken")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
        .alert("KI-Anbieter nicht konfiguriert", isPresented: $showAIKeyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Bitte richte zuerst einen KI-Anbieter in den Einstellungen ein.")
        }
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: 12) {
            summaryTile(value: "\(completedTodos.count)", label: "Erledigt", color: .green)
            summaryTile(value: bestWeekday, label: "Bester Tag", color: .blue)
            summaryTile(value: bestTimeBlock, label: "Beste Zeit", color: .orange)
        }
    }

    private func summaryTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Weekday Chart

    private var weekdayCard: some View {
        statCard(title: "Wochentag-Produktivität", icon: "calendar.badge.checkmark", color: .blue) {
            barChart(data: weekdayData, color: .blue)
        }
    }

    // MARK: - Time Chart

    private var timeCard: some View {
        statCard(title: "Tageszeit-Analyse", icon: "clock.fill", color: .orange) {
            barChart(data: timeData, color: .orange)
        }
    }

    // MARK: - Category Card

    private var categoryCard: some View {
        statCard(title: "Kategorie-Abschlussquote", icon: "tag.fill", color: .purple) {
            VStack(spacing: 10) {
                ForEach(categoryData, id: \.name) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            Text(item.name)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.done)/\(item.total)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text("\(Int(item.rate * 100))%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(item.color)
                                .frame(width: 36, alignment: .trailing)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(item.color.opacity(0.15))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(item.color.opacity(0.8))
                                    .frame(width: geo.size.width * CGFloat(item.rate), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }

    // MARK: - Priority Card

    private var priorityCard: some View {
        statCard(title: "Prioritäts-Abschlussquote", icon: "flag.fill", color: .red) {
            HStack(spacing: 16) {
                ForEach(priorityData, id: \.label) { item in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(item.color.opacity(0.2), lineWidth: 6)
                                .frame(width: 56, height: 56)
                            Circle()
                                .trim(from: 0, to: CGFloat(item.rate))
                                .stroke(item.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 56, height: 56)
                                .animation(.easeOut(duration: 0.6), value: item.rate)
                            Text("\(Int(item.rate * 100))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(item.color)
                        }
                        Text(item.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - AI Insight Card

    private var insightCard: some View {
        statCard(title: "KI-Produktivitäts-Insight", icon: "sparkles", color: Color(red: 0.55, green: 0.35, blue: 1.0)) {
            VStack(alignment: .leading, spacing: 12) {
                if insightText.isEmpty && !isGeneratingInsight {
                    Text("Lass die KI deine Produktivitätsmuster analysieren und einen persönlichen Insight generieren.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(insightText.isEmpty ? "Analysiere…" : insightText)
                        .font(.system(size: 13))
                        .foregroundStyle(insightText.isEmpty ? .secondary : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(.easeIn, value: insightText)
                }

                Button {
                    if isGeneratingInsight {
                        insightTask?.cancel()
                        isGeneratingInsight = false
                    } else {
                        insightTask = Task { await generateInsight() }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isGeneratingInsight {
                            ProgressView().scaleEffect(0.75)
                            Text("Stopp")
                        } else {
                            Image(systemName: "sparkles")
                            Text(insightText.isEmpty ? "Insight generieren" : "Neu generieren")
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.55, green: 0.35, blue: 1.0))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color(red: 0.55, green: 0.35, blue: 1.0).opacity(0.12))
                    )
                    .overlay(Capsule().stroke(Color(red: 0.55, green: 0.35, blue: 1.0).opacity(0.3), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: isGeneratingInsight)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statCard<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            content()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func barChart(data: [(label: String, value: Int)], color: Color) -> some View {
        let maxVal = max(data.map(\.value).max() ?? 1, 1)
        let maxHeight: CGFloat = 90

        return VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(data, id: \.label) { item in
                    VStack(spacing: 3) {
                        if item.value > 0 {
                            Text("\(item.value)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        } else {
                            Color.clear.frame(height: 13)
                        }
                        RoundedRectangle(cornerRadius: 5)
                            .fill(color.opacity(item.value > 0 ? 0.75 : 0.12))
                            .frame(height: max(4, maxHeight * CGFloat(item.value) / CGFloat(maxVal)))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: maxHeight + 16)

            HStack(spacing: 4) {
                ForEach(data, id: \.label) { item in
                    Text(item.label)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - AI Insight Generation

    private func generateInsight() async {
        guard completedTodos.count >= 3 else {
            await MainActor.run {
                insightText = "Noch zu wenig Daten. Schließe mehr Aufgaben ab, um einen Insight zu erhalten."
            }
            return
        }
        isGeneratingInsight = true
        insightText = ""

        let topDay = weekdayData.max(by: { $0.value < $1.value })
        let topTime = timeData.max(by: { $0.value < $1.value })
        let topCat = categoryData.first

        var context = "Abgeschlossene Aufgaben insgesamt: \(completedTodos.count)\n"
        if let d = topDay, d.value > 0 { context += "Produktivster Wochentag: \(d.label) (\(d.value) Aufgaben)\n" }
        if let t = topTime, t.value > 0 { context += "Aktivste Tageszeit: \(t.label) Uhr (\(t.value) Aufgaben)\n" }
        if let c = topCat { context += "Stärkste Kategorie: \(c.name) (\(Int(c.rate * 100))% Abschlussquote)\n" }
        for p in priorityData { context += "Priorität \(p.label): \(Int(p.rate * 100))%\n" }

        let prompt = """
        Analysiere diese Produktivitätsdaten eines App-Nutzers und gib einen kurzen, persönlichen und motivierenden Insight auf Deutsch.
        \(context)
        Regeln:
        - Maximal 3 Sätze
        - Konkret auf die Daten eingehen
        - Positiv und motivierend formulieren
        - Kein Markdown, keine Aufzählung
        - Antworte NUR mit dem Insight
        """

        var raw = ""
        do {
            switch aiProvider {
            case "apple":
                if #available(iOS 26.0, *) {
                    guard case .available = SystemLanguageModel.default.availability else {
                        isGeneratingInsight = false; return
                    }
                    let session = LanguageModelSession()
                    for try await partial in session.streamResponse(to: prompt) {
                        try Task.checkCancellation()
                        raw = partial.content
                        await MainActor.run { insightText = raw }
                    }
                }
            case "openai":
                guard let key = KeychainHelper.load(for: OpenAIService.keychainKey), !key.isEmpty else {
                    await MainActor.run { showAIKeyAlert = true; isGeneratingInsight = false }; return
                }
                for try await chunk in OpenAIService.stream(prompt: prompt, apiKey: key, model: openaiModel) {
                    try Task.checkCancellation()
                    raw += chunk
                    await MainActor.run { insightText = raw }
                }
            case "groq":
                guard let key = KeychainHelper.load(for: GroqService.keychainKey), !key.isEmpty else {
                    await MainActor.run { showAIKeyAlert = true; isGeneratingInsight = false }; return
                }
                for try await chunk in GroqService.stream(prompt: prompt, apiKey: key, model: groqModel) {
                    try Task.checkCancellation()
                    raw += chunk
                    await MainActor.run { insightText = raw }
                }
            default:
                guard let key = KeychainHelper.load(for: GeminiService.keychainKey), !key.isEmpty else {
                    await MainActor.run { showAIKeyAlert = true; isGeneratingInsight = false }; return
                }
                for try await chunk in GeminiService.stream(prompt: prompt, apiKey: key) {
                    try Task.checkCancellation()
                    raw += chunk
                    await MainActor.run { insightText = raw }
                }
            }
        } catch is CancellationError {
            // partial result stays
        } catch {
            // keep partial
        }
        await MainActor.run { isGeneratingInsight = false }
    }
}

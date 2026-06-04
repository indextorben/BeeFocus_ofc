import SwiftUI

struct FokusJournalView: View {
    @ObservedObject private var store = JournalStore.shared
    @ObservedObject private var sub = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var showEntrySheet = false
    @State private var entrySheetDate: Date = Date()
    @State private var editEntry: JournalEntry? = nil
    @State private var showAIAnalysis = false
    @State private var aiAnalysisText = ""
    @State private var isLoadingAI = false

    private var last7Days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    private var c1: Color { appThemaFarben(aktivesThema).0 }
    private var c2: Color { appThemaFarben(aktivesThema).1 }
    private var accent: Color { aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : c1 }

    // Free tier: only last 7 entries visible without Pro
    private var visibleEntries: [JournalEntry] {
        sub.isPro ? store.entries : Array(store.entries.prefix(7))
    }

    var body: some View {
        ZStack {
            ThemeBackgroundView().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    headerSection.padding(.top, 24).padding(.horizontal, 20)

                    // Weekly overview + backfill
                    weeklyStatsCard
                        .padding(.horizontal, 20)

                    // Today prompt
                    if !store.hasTodayEntry() {
                        todayPromptCard
                            .padding(.horizontal, 20)
                    }

                    // AI Analysis button (Pro)
                    if store.entries.count >= 3 {
                        aiAnalysisButton
                            .padding(.horizontal, 20)
                    }

                    // Entry list
                    if store.entries.isEmpty {
                        emptyState.padding(.top, 20).padding(.horizontal, 20)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(visibleEntries) { entry in
                                JournalEntryCard(entry: entry, accent: accent) {
                                    editEntry = entry
                                } onDelete: {
                                    store.delete(entry)
                                }
                            }

                            // Lock banner for free users
                            if !sub.isPro && store.entries.count > 7 {
                                proLockBanner
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 32)
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 20)
                }
                Spacer()
            }

            // AI overlay
            if showAIAnalysis {
                aiOverlay
            }
        }
        .sheet(isPresented: $showEntrySheet) {
            JournalEntrySheet(existing: nil, initialDate: entrySheetDate, accent: accent)
        }
        .sheet(item: $editEntry) { entry in
            JournalEntrySheet(existing: entry, accent: accent)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Focus Journal")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(store.entries.count) entries total")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Button {
                entrySheetDate = Date()
                showEntrySheet = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(accent.opacity(0.15), in: Circle())
            }
        }
    }

    // MARK: - Today Prompt

    private var todayPromptCard: some View {
        Button { entrySheetDate = Date(); showEntrySheet = true } label: {
            HStack(spacing: 14) {
                Text("✍️")
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 3) {
                    Text("How was your day?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Write today's reflection")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(accent.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(accent.opacity(0.35), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekly Stats

    private var weeklyStatsCard: some View {
        let recentEntries = store.recentEntries(days: 7)
        let count = recentEntries.count
        let avgMood = count > 0 ? Double(recentEntries.map(\.moodScore).reduce(0, +)) / Double(count) : 0.0
        let totalFocus = recentEntries.map(\.focusMinutes).reduce(0, +)
        let hours = totalFocus / 60
        let mins = totalFocus % 60
        let cal = Calendar.current

        return VStack(alignment: .leading, spacing: 14) {
            Text("This Week")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 0) {
                ForEach(last7Days, id: \.self) { date in
                    let existing = store.entry(for: date)
                    let isToday = cal.isDateInToday(date)
                    Button {
                        if let e = existing {
                            editEntry = e
                        } else {
                            entrySheetDate = date
                            showEntrySheet = true
                        }
                    } label: {
                        VStack(spacing: 5) {
                            if let e = existing {
                                Text(e.moodEmoji)
                                    .font(.system(size: 22))
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(isToday ? accent.opacity(0.18) : Color.white.opacity(0.06))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(isToday ? accent : .white.opacity(0.25))
                                }
                            }
                            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.system(size: 9))
                                .foregroundStyle(isToday ? accent : .white.opacity(0.35))
                                .fontWeight(isToday ? .bold : .regular)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }

            if count > 0 {
                Divider().background(.white.opacity(0.08))
                HStack(spacing: 0) {
                    weekStatItem(value: "\(count)/7", label: "Days")
                    if avgMood > 0 {
                        Divider().frame(height: 28).background(.white.opacity(0.1))
                        weekStatItem(
                            value: String(format: "%.1f", avgMood),
                            label: "Ø Mood",
                            color: moodColor(for: avgMood)
                        )
                    }
                    if totalFocus > 0 {
                        Divider().frame(height: 28).background(.white.opacity(0.1))
                        weekStatItem(
                            value: hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m",
                            label: "Focus time"
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private func weekStatItem(value: String, label: String, color: Color = .white) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - AI Analysis

    private var aiAnalysisButton: some View {
        Button {
            guard sub.isPro else {
                NotificationCenter.default.post(name: .showPaywall, object: nil)
                dismiss()
                return
            }
            runAIAnalysis()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isLoadingAI ? "ellipsis" : "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(sub.isPro ? accent : .gray)
                    .symbolEffect(.variableColor, isActive: isLoadingAI)
                Text(isLoadingAI ? "Analyzing..." : "AI Weekly Analysis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(sub.isPro ? .white : .white.opacity(0.4))
                Spacer()
                if !sub.isPro {
                    Text("Pro")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(red: 0.55, green: 0.35, blue: 1.0), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isLoadingAI)
    }

    private func moodColor(for avg: Double) -> Color {
        switch avg {
        case ..<2.5: return Color(red: 0.9, green: 0.3, blue: 0.3)
        case ..<3.5: return Color(red: 0.9, green: 0.7, blue: 0.2)
        default:     return Color(red: 0.3, green: 0.85, blue: 0.4)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("📓")
                .font(.system(size: 48))
            Text("No entries yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("Daily record what went well, what distracted you and what matters tomorrow.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    // MARK: - Pro Lock

    private var proLockBanner: some View {
        Button {
            NotificationCenter.default.post(name: .showPaywall, object: nil)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(accent)
                Text("Unlock Pro for full history")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
            .padding(16)
            .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - AI Overlay

    private var aiOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
                .onTapGesture { showAIAnalysis = false }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(accent)
                    Text("AI Weekly Analysis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button { showAIAnalysis = false } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                ScrollView {
                    Text(aiAnalysisText)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineSpacing(4)
                }
                .frame(maxHeight: 300)
            }
            .padding(20)
            .background(Color(red: 0.1, green: 0.08, blue: 0.18), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
            .padding(24)
        }
    }

    // MARK: - AI Analysis Logic

    private func runAIAnalysis() {
        isLoadingAI = true
        aiAnalysisText = ""
        let entries = store.recentEntries(days: 7)
        guard !entries.isEmpty else { isLoadingAI = false; return }

        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .none
        let summary = entries.map { e in
            "Datum: \(df.string(from: e.date)), Stimmung: \(e.moodScore)/5, Gut lief: \(e.wentWell), Ablenkung: \(e.distraction), Morgen-Ziel: \(e.tomorrowPriority)"
        }.joined(separator: "\n")

        let prompt = "You are a productivity coach. Analyze these focus journal entries from the past week and provide a short, motivating analysis (3–5 sentences) with concrete insights and one tip. No Markdown.\n\n\(summary)"

        let provider = UserDefaults.standard.string(forKey: "aiProvider") ?? "gemini"

        Task {
            do {
                var result = ""
                let stream: AsyncThrowingStream<String, Error>
                switch provider {
                case "openai":
                    guard let key = KeychainHelper.load(for: OpenAIService.keychainKey) else { throw NSError(domain: "", code: 0) }
                    stream = OpenAIService.stream(prompt: prompt, apiKey: key, model: "gpt-4o-mini")
                case "groq":
                    guard let key = KeychainHelper.load(for: GroqService.keychainKey) else { throw NSError(domain: "", code: 0) }
                    stream = GroqService.stream(prompt: prompt, apiKey: key, model: "llama-3.3-70b-versatile")
                default:
                    guard let key = KeychainHelper.load(for: GeminiService.keychainKey) else { throw NSError(domain: "", code: 0) }
                    stream = GeminiService.stream(prompt: prompt, apiKey: key)
                }
                for try await chunk in stream { result += chunk }
                await MainActor.run {
                    aiAnalysisText = result
                    isLoadingAI = false
                    showAIAnalysis = true
                }
            } catch {
                await MainActor.run {
                    aiAnalysisText = "AI not available. Please check your API key in Settings."
                    isLoadingAI = false
                    showAIAnalysis = true
                }
            }
        }
    }
}

// MARK: - Entry Card

struct JournalEntryCard: View {
    let entry: JournalEntry
    let accent: Color
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                Text(entry.moodEmoji)
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.date.formatted(date: .complete, time: .omitted))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(entry.moodLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(entry.moodColor)
                }

                Spacer()

                if entry.focusMinutes > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 11))
                        Text("\(entry.focusMinutes)min")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.45))
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(16)

            // Expanded content
            if isExpanded {
                Divider()
                    .background(.white.opacity(0.1))
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {
                    if !entry.wentWell.isEmpty {
                        journalField(label: "✅ What went well", text: entry.wentWell)
                    }
                    if !entry.distraction.isEmpty {
                        journalField(label: "⚡ Distraction", text: entry.distraction)
                    }
                    if !entry.tomorrowPriority.isEmpty {
                        journalField(label: "🎯 Tomorrow's goal", text: entry.tomorrowPriority)
                    }

                    HStack {
                        Button("Edit") { onEdit() }
                            .font(.system(size: 13))
                            .foregroundStyle(accent)
                        Spacer()
                        Button("Delete", role: .destructive) { onDelete() }
                            .font(.system(size: 13))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func journalField(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

// MARK: - Entry Sheet

struct JournalEntrySheet: View {
    let existing: JournalEntry?
    var initialDate: Date = Date()
    let accent: Color

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = JournalStore.shared

    @State private var selectedDate: Date = Date()
    @State private var moodScore: Int = 3
    @State private var wentWell: String = ""
    @State private var distraction: String = ""
    @State private var tomorrowPriority: String = ""
    @State private var focusMinutes: Int = 0

    private var maxBackfillDate: Date { Date() }
    private var minBackfillDate: Date {
        Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.14).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Mood selector
                        VStack(spacing: 12) {
                            Text("Wie war dein Tag?")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)

                            HStack(spacing: 0) {
                                ForEach(1...5, id: \.self) { score in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            moodScore = score
                                        }
                                    } label: {
                                        VStack(spacing: 6) {
                                            Text(JournalEntry.moods[score - 1].emoji)
                                                .font(.system(size: moodScore == score ? 38 : 26))
                                                .animation(.spring(response: 0.3), value: moodScore)
                                            Text(JournalEntry.moods[score - 1].label)
                                                .font(.system(size: 9))
                                                .foregroundStyle(moodScore == score
                                                                 ? JournalEntry.moods[score - 1].color
                                                                 : .white.opacity(0.3))
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                        }

                        // Date picker (only for new entries)
                        if existing == nil {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(accent)
                                Text("Datum")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white)
                                Spacer()
                                DatePicker(
                                    "",
                                    selection: $selectedDate,
                                    in: minBackfillDate...maxBackfillDate,
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                                .colorScheme(.dark)
                                .tint(accent)
                            }
                            .padding(14)
                            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                        }

                        // Focus minutes
                        HStack {
                            Image(systemName: "timer")
                                .foregroundStyle(accent)
                            Text("Heute fokussiert")
                                .font(.system(size: 15))
                                .foregroundStyle(.white)
                            Spacer()
                            Stepper("\(focusMinutes) min", value: $focusMinutes, in: 0...480, step: 5)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .tint(accent)
                        }
                        .padding(14)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))

                        // Text fields
                        journalField(
                            emoji: "✅",
                            label: "Was lief heute gut?",
                            placeholder: "Erfolgserlebnisse, Fortschritte...",
                            text: $wentWell
                        )
                        journalField(
                            emoji: "⚡",
                            label: "What distracted me?",
                            placeholder: "Disruptions, energy drains...",
                            text: $distraction
                        )
                        journalField(
                            emoji: "🎯",
                            label: "My most important goal for tomorrow",
                            placeholder: "The one task that counts...",
                            text: $tomorrowPriority
                        )
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(existing == nil ? "Daily Review" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(accent)
                }
            }
            .onAppear {
                if let e = existing {
                    moodScore        = e.moodScore
                    wentWell         = e.wentWell
                    distraction      = e.distraction
                    tomorrowPriority = e.tomorrowPriority
                    focusMinutes     = e.focusMinutes
                    selectedDate     = e.date
                } else {
                    focusMinutes = 0
                    selectedDate = initialDate
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func journalField(emoji: String, label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(emoji)
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            TextEditor(text: text)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 70, maxHeight: 120)
                .padding(12)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    Group {
                        if text.wrappedValue.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.25))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                )
        }
    }

    private func save() {
        var entry = existing ?? JournalEntry()
        entry.moodScore        = moodScore
        entry.wentWell         = wentWell
        entry.distraction      = distraction
        entry.tomorrowPriority = tomorrowPriority
        entry.focusMinutes     = focusMinutes
        if existing == nil { entry.date = selectedDate }
        store.save(entry)
        dismiss()
    }
}

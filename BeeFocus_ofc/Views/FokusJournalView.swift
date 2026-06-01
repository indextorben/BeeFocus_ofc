import SwiftUI

struct FokusJournalView: View {
    @ObservedObject private var store = JournalStore.shared
    @ObservedObject private var sub = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var showEntrySheet = false
    @State private var editEntry: JournalEntry? = nil
    @State private var showAIAnalysis = false
    @State private var aiAnalysisText = ""
    @State private var isLoadingAI = false

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

                    // Mood trend
                    if store.entries.count >= 3 {
                        moodTrendCard
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
            JournalEntrySheet(existing: nil, accent: accent)
        }
        .sheet(item: $editEntry) { entry in
            JournalEntrySheet(existing: entry, accent: accent)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Fokus-Journal")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(store.entries.count) Einträge gesamt")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Button {
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
        Button { showEntrySheet = true } label: {
            HStack(spacing: 14) {
                Text("✍️")
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Wie war dein Tag?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Heutigen Rückblick schreiben")
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
                Text(isLoadingAI ? "Analysiere..." : "KI-Wochenanalyse")
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

    // MARK: - Mood Trend

    private var moodTrendCard: some View {
        let recent = store.recentEntries(days: 7).reversed().map { $0 }
        let avg = store.averageMood(last: 7)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Stimmungstrend (7 Tage)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if avg > 0 {
                    Text(String(format: "Ø %.1f", avg))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(moodColor(for: avg))
                }
            }

            HStack(spacing: 6) {
                ForEach(recent, id: \.id) { entry in
                    VStack(spacing: 4) {
                        Text(entry.moodEmoji)
                            .font(.system(size: 20))
                        Text(entry.date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal, 20)
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
            Text("Kein Eintrag bisher")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("Halte täglich fest was gut lief, was dich ablenkte und was morgen wichtig ist.")
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
                Text("Pro freischalten für vollständigen Verlauf")
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
                    Text("KI-Wochenanalyse")
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

        let prompt = "Du bist ein Produktivitäts-Coach. Analysiere diese Fokus-Tagebuch-Einträge der letzten Woche und gib eine kurze, motivierende Analyse (3–5 Sätze) mit konkreten Erkenntnissen und einem Tipp. Kein Markdown.\n\n\(summary)"

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
                    aiAnalysisText = "KI nicht verfügbar. Bitte API-Schlüssel in den Einstellungen prüfen."
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
                        journalField(label: "✅ Was lief gut", text: entry.wentWell)
                    }
                    if !entry.distraction.isEmpty {
                        journalField(label: "⚡ Ablenkung", text: entry.distraction)
                    }
                    if !entry.tomorrowPriority.isEmpty {
                        journalField(label: "🎯 Morgen-Ziel", text: entry.tomorrowPriority)
                    }

                    HStack {
                        Button("Bearbeiten") { onEdit() }
                            .font(.system(size: 13))
                            .foregroundStyle(accent)
                        Spacer()
                        Button("Löschen", role: .destructive) { onDelete() }
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
    let accent: Color

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = JournalStore.shared

    @State private var moodScore: Int = 3
    @State private var wentWell: String = ""
    @State private var distraction: String = ""
    @State private var tomorrowPriority: String = ""
    @State private var focusMinutes: Int = 0

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
                            label: "Was hat mich abgelenkt?",
                            placeholder: "Störungen, Energiefresser...",
                            text: $distraction
                        )
                        journalField(
                            emoji: "🎯",
                            label: "Mein wichtigstes Ziel für morgen",
                            placeholder: "Die eine Aufgabe die zählt...",
                            text: $tomorrowPriority
                        )
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(existing == nil ? "Tagesrückblick" : "Eintrag bearbeiten")
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
                } else {
                    focusMinutes = 0
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
        if existing == nil { entry.date = Date() }
        store.save(entry)
        dismiss()
    }
}

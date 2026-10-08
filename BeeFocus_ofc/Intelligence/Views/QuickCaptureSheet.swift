//
//  QuickCaptureSheet.swift
//  BeeFocus_ofc
//
//  "Schnell erfassen": einen Satz sprechen oder tippen – BeeFocus erkennt
//  Titel, Tag, Uhrzeit und Priorität und legt die Aufgabe an.
//  Braucht kein Apple Intelligence und läuft darum auf jedem Gerät.
//

import SwiftUI

struct QuickCaptureSheet: View {
    @EnvironmentObject private var todoStore: TodoStore
    @ObservedObject private var speech = SpeechManager.shared
    @ObservedObject private var localizer = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    /// Vorbelegter Text, z. B. aus einem Kurzbefehl.
    var initialText: String = ""

    @State private var text: String = ""
    @State private var drafts: [QuickTodoDraft] = []
    @FocusState private var inputFocused: Bool

    /// Soll Apple Intelligence den Entwurf verfeinern? Auf Geräten ohne
    /// Apple Intelligence hat der Schalter keine Wirkung.
    @AppStorage("aiRefineCapture") private var refineWithAI: Bool = true

    @State private var isRefining = false
    @State private var refineError: String?
    @State private var refineTask: Task<Void, Never>?
    /// Eingabe, für die schon verfeinert wurde – verhindert Mehrfachanfragen.
    @State private var refinedText = ""

    private var c1: Color { appThemaFarben(aktivesThema).0 }
    private var c2: Color { appThemaFarben(aktivesThema).1 }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Steht Apple Intelligence zum Verfeinern bereit?
    private var canRefine: Bool { AIFeature.isReady }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        inputCard

                        if isRefining || refineError != nil {
                            statusCard
                        }

                        if drafts.isEmpty {
                            examplesCard
                        } else {
                            ForEach(Array(drafts.enumerated()), id: \.offset) { index, draft in
                                resultCard(index: index, draft: draft)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(localizer.localizedString(forKey: "quick_capture_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localizer.localizedString(forKey: "brain_close")) {
                        if speech.isRecording { speech.stopRecording() }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizer.localizedString(forKey: "quick_capture_save")) { save() }
                        .fontWeight(.semibold)
                        .disabled(drafts.isEmpty)
                }
            }
            .onAppear {
                speech.requestPermissions()
                if text.isEmpty, !initialText.isEmpty {
                    text = initialText
                    recompute()
                    scheduleRefine()
                }
                if text.isEmpty { inputFocused = true }
            }
            .onDisappear {
                if speech.isRecording { speech.stopRecording() }
                refineTask?.cancel()
            }
            // Diktat schreibt direkt ins Eingabefeld.
            .onChange(of: speech.liveText) { _, new in
                guard speech.isRecording, !new.isEmpty else { return }
                text = new
                recompute()
            }
            .onChange(of: text) { _, _ in
                recompute()
                scheduleRefine()
            }
        }
    }

    // MARK: - Eingabe

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(c1)
                Text(localizer.localizedString(forKey: "quick_capture_hint"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            TextField(
                localizer.localizedString(forKey: "quick_capture_placeholder"),
                text: $text,
                axis: .vertical
            )
            .font(.system(size: 17))
            .lineLimit(1...5)
            .focused($inputFocused)

            HStack(spacing: 10) {
                Button {
                    toggleRecording()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(localizer.localizedString(
                            forKey: speech.isRecording ? "quick_capture_stop" : "quick_capture_speak"
                        ))
                        .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(colors: speech.isRecording ? [.red, .orange] : [c1, c2],
                                       startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)

                if speech.isRecording {
                    AIWaveform(level: speech.audioLevel, isActive: true, barCount: 14)
                        .frame(height: 24)
                } else if canRefine {
                    refineToggle
                }

                Spacer()

                if !text.isEmpty {
                    Button {
                        text = ""
                        drafts = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    // MARK: - Ergebnis

    private func resultCard(index: Int, draft: QuickTodoDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(draft.title)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if draft.isAIRefined {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(c1)
                }
            }

            if !draft.details.isEmpty {
                Text(draft.details)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !draft.subtasks.isEmpty {
                subtaskList(index: index, items: draft.subtasks)
            }

            HStack(spacing: 8) {
                if let due = draft.dueDate {
                    chip(
                        icon: draft.hasTime ? "clock.fill" : "calendar",
                        text: dueLabel(due, hasTime: draft.hasTime),
                        color: c1
                    )
                } else {
                    chip(icon: "calendar.badge.plus",
                         text: localizer.localizedString(forKey: "quick_capture_no_date"),
                         color: .secondary)
                }

                chip(icon: priorityIcon(draft.priority),
                     text: priorityLabel(draft.priority),
                     color: priorityColor(draft.priority))

                Spacer()
            }

            // Kleine Korrekturen ohne Umweg über den Editor.
            HStack(spacing: 10) {
                if let due = draft.dueDate {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { due },
                            set: { drafts[index].dueDate = $0; drafts[index].hasTime = true }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                } else {
                    Button {
                        drafts[index].dueDate = Calendar.current.date(
                            bySettingHour: 9, minute: 0, second: 0, of: Date()
                        )
                    } label: {
                        Text(localizer.localizedString(forKey: "quick_capture_add_date"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(c1)
                }

                Spacer()

                Picker("", selection: Binding(
                    get: { drafts[index].priority },
                    set: { drafts[index].priority = $0 }
                )) {
                    ForEach(TodoPriority.allCases) { p in
                        Text(priorityLabel(p)).tag(p)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(c1)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    /// Schalter: Soll Apple Intelligence den Entwurf verfeinern?
    private var refineToggle: some View {
        Button {
            refineWithAI.toggle()
            if refineWithAI {
                refinedText = ""
                scheduleRefine(immediately: true)
            } else {
                refineTask?.cancel()
                isRefining = false
                refineError = nil
                recompute()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                Text(localizer.localizedString(forKey: "quick_capture_refine"))
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(refineWithAI ? c1 : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(refineWithAI ? c1.opacity(0.14) : Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            if isRefining {
                ProgressView().controlSize(.small)
                Text(localizer.localizedString(forKey: "quick_capture_refining"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else if let refineError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                Text(refineError)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardBackground)
    }

    /// Die erkannten Einzelteile – z. B. die Dinge einer Einkaufsliste.
    /// Jeder Eintrag lässt sich hier schon wieder entfernen.
    private func subtaskList(index: Int, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "list.bullet.indent")
                    .font(.system(size: 10, weight: .semibold))
                Text(localizer.localizedString(forKey: "quick_capture_steps_title"))
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.secondary)

            ForEach(Array(items.enumerated()), id: \.offset) { itemIndex, item in
                HStack(spacing: 8) {
                    Image(systemName: "circle")
                        .font(.system(size: 9))
                        .foregroundStyle(c1.opacity(0.7))
                    Text(item)
                        .font(.system(size: 14))
                    Spacer()
                    Button {
                        guard drafts.indices.contains(index),
                              drafts[index].subtasks.indices.contains(itemIndex) else { return }
                        withAnimation { drafts[index].subtasks.remove(at: itemIndex) }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var examplesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizer.localizedString(forKey: "quick_capture_examples_title"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(exampleSentences, id: \.self) { example in
                Button {
                    text = example
                    recompute()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 10))
                            .foregroundStyle(c1.opacity(0.7))
                        Text(example)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary.opacity(0.85))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var exampleSentences: [String] {
        [
            localizer.localizedString(forKey: "quick_capture_example_1"),
            localizer.localizedString(forKey: "quick_capture_example_2"),
            localizer.localizedString(forKey: "quick_capture_example_3")
        ]
    }

    // MARK: - Bausteine

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(c1.opacity(0.25), lineWidth: 1)
        }
    }

    private func chip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }

    private func dueLabel(_ date: Date, hasTime: Bool) -> String {
        let cal = Calendar.current
        let time = DateFormatter()
        time.locale = Locale.current
        time.dateFormat = "HH:mm"

        let day: String
        if cal.isDateInToday(date) {
            day = localizer.localizedString(forKey: "quick_capture_today")
        } else if cal.isDateInTomorrow(date) {
            day = localizer.localizedString(forKey: "quick_capture_tomorrow")
        } else {
            let f = DateFormatter()
            f.locale = Locale.current
            f.setLocalizedDateFormatFromTemplate("EEE d. MMM")
            day = f.string(from: date)
        }

        return hasTime ? "\(day), \(time.string(from: date))" : day
    }

    private func priorityLabel(_ p: TodoPriority) -> String {
        switch p {
        case .high: return localizer.localizedString(forKey: "priority_high")
        case .medium: return localizer.localizedString(forKey: "priority_medium")
        case .low: return localizer.localizedString(forKey: "priority_low")
        }
    }

    private func priorityIcon(_ p: TodoPriority) -> String {
        switch p {
        case .high: return "exclamationmark.2"
        case .medium: return "equal"
        case .low: return "arrow.down"
        }
    }

    private func priorityColor(_ p: TodoPriority) -> Color {
        switch p {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }

    /// Diktiersprache passend zur App-Sprache.
    private var recordingLanguage: String {
        switch localizer.currentLanguageCode {
        case "en": return "en-US"
        case "fr": return "fr-FR"
        case "es": return "es-ES"
        default:   return "de-DE"
        }
    }

    // MARK: - Logik

    /// Analysiert den Text neu, behält aber manuelle Korrekturen und bereits
    /// verfeinerte Entwürfe bei, solange die zugehörige Eingabe gleich bleibt.
    private func recompute() {
        let parsed = QuickTodoParser.drafts(from: text)
        guard parsed.count == drafts.count else {
            drafts = parsed
            return
        }
        for (index, new) in parsed.enumerated() {
            // Verfeinerte Entwürfe nur ersetzen, wenn sich ihre Eingabe geändert hat.
            if drafts[index].isAIRefined, drafts[index].source == new.source { continue }
            if drafts[index].source == new.source, drafts[index].title == new.title { continue }
            drafts[index] = new
        }
    }

    /// Startet die Verfeinerung, sobald der Nutzer eine kurze Pause macht.
    private func scheduleRefine(immediately: Bool = false) {
        refineTask?.cancel()
        refineError = nil
        guard canRefine, refineWithAI, !speech.isRecording else { return }

        let input = trimmedText
        guard input.count >= 6, input != refinedText else { return }

        refineTask = Task {
            if !immediately {
                try? await Task.sleep(for: .milliseconds(1200))
            }
            guard !Task.isCancelled, trimmedText == input else { return }
            await runRefine(for: input)
        }
    }

    private func runRefine(for input: String) async {
        guard #available(iOS 26.0, *) else { return }
        let base = drafts
        guard !base.isEmpty else { return }

        isRefining = true
        defer { isRefining = false }

        let refined = await AITodoIntelligence.shared.refine(base)
        // Während der Anfrage darf der Nutzer weitergetippt haben.
        guard !Task.isCancelled, trimmedText == input, drafts.count == refined.count else { return }

        refinedText = input
        withAnimation { drafts = refined }
        if refined.allSatisfy({ !$0.isAIRefined }) {
            refineError = localizer.localizedString(forKey: "quick_capture_refine_failed")
        }
    }

    private func toggleRecording() {
        if speech.isRecording {
            speech.stopRecording()
            // Erst nach dem Diktat verfeinern – während des Sprechens wächst
            // der Text ja noch Wort für Wort.
            scheduleRefine(immediately: true)
        } else {
            inputFocused = false
            speech.liveText = ""
            speech.startRecording(languageCode: recordingLanguage)
        }
    }

    private func save() {
        guard !drafts.isEmpty else { return }
        refineTask?.cancel()
        for draft in drafts {
            todoStore.addTodo(draft.makeTodo())
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

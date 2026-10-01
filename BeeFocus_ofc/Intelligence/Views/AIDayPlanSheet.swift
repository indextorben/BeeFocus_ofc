//
//  AIDayPlanSheet.swift
//  BeeFocus_ofc
//
//  "Bee Brain": Alles rausreden oder reintippen – und einen sortierten,
//  zeitgeblockten Tag zurückbekommen.
//

import PhotosUI
import SwiftUI

@available(iOS 26.0, *)
struct AIDayPlanSheet: View {
    /// Vorbelegter Text, z. B. aus dem Brain Dump.
    var initialText: String = ""
    /// Direkt mit dem Planen starten, ohne Texteingabe.
    var startWithExistingTodos: Bool = false

    @StateObject private var planner = AIPlanner()
    @ObservedObject private var availability = AIAvailability.shared
    @ObservedObject private var speech = SpeechManager.shared
    @ObservedObject private var localizer = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @State private var braindump: String = ""
    @State private var includeExisting = true
    @State private var stage: Stage = .input
    @State private var appliedCount: Int?
    // Foto -> Aufgaben
    @State private var photoItem: PhotosPickerItem?
    @State private var isReadingPhoto = false
    @State private var photoError: String?
    @FocusState private var inputFocused: Bool

    private enum Stage { case input, review, plan }

    private var accent: Color { AIAccent.color(for: aktivesThema) }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView().ignoresSafeArea()

                if availability.isAvailable {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            switch stage {
                            case .input:  inputStage
                            case .review: reviewStage
                            case .plan:   planStage
                            }

                            if case .failed(let message) = planner.phase {
                                AIErrorRow(message: message)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                } else {
                    ScrollView { AIUnavailableCard().padding(20) }
                }
            }
            .navigationTitle(AIL("ai_plan_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localizer.localizedString(forKey: "brain_close")) {
                        planner.cancel()
                        speech.stopRecording()
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
                if stage != .input {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(AIL("ai_plan_restart")) {
                            planner.reset()
                            stage = .input
                            appliedCount = nil
                        }
                        .foregroundStyle(accent)
                    }
                }
                // Die Eingabetaste legt im mehrzeiligen Feld eine neue Zeile an.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(AIL("done")) { inputFocused = false }
                }
            }
            .onAppear(perform: setup)
            .onDisappear {
                planner.cancel()
                speech.stopRecording()
            }
            .onChange(of: planner.phase) { _, newValue in
                // Nach der Extraktion in die Prüfansicht, nach dem Planen in die Planansicht.
                guard newValue == .ready else { return }
                if planner.plan != nil {
                    stage = .plan
                } else if !planner.candidates.isEmpty {
                    stage = .review
                }
            }
        }
    }

    private func setup() {
        availability.refresh()
        AIAvailability.shared.prewarm()
        if !initialText.isEmpty && braindump.isEmpty {
            braindump = initialText
        }
        if startWithExistingTodos {
            stage = .plan
            planner.buildPlan(includeExistingTodos: true)
        }
    }

    // MARK: - Stufe 1: Eingabe

    private var inputStage: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    AIBadge(text: "Apple Intelligence")
                    Spacer()
                }

                Text(AIL("ai_plan_input_title"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Text(AIL("ai_plan_input_subtitle"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)

                // Mitwachsendes TextField statt TextEditor: in einer ScrollView
                // bekommt ein TextEditor keine feste Höhe angeboten, fällt auf
                // Höhe 0 zusammen und nimmt keine Eingabe mehr an.
                TextField(AIL("ai_plan_placeholder"), text: $braindump, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(6...14)
                    .focused($inputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.07))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onTapGesture { inputFocused = true }

                if speech.isRecording {
                    AIWaveform(level: speech.audioLevel, isActive: true)
                        .onChange(of: speech.liveText) { _, newValue in
                            braindump = newValue
                        }
                }

                HStack(spacing: 10) {
                    Button {
                        if speech.isRecording {
                            speech.stopRecording()
                        } else {
                            speech.autoStopOnFinal = false
                            speech.startRecording(languageCode: recordingLanguage)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                            Text(speech.isRecording ? AIL("ai_plan_stop_dictation") : AIL("ai_plan_dictate"))
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(speech.isRecording ? AnyShapeStyle(Color.red) : AnyShapeStyle(Color.white.opacity(0.12)))
                        )
                    }

                    // Whiteboard oder Zettel abfotografieren.
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        HStack(spacing: 6) {
                            if isReadingPhoto {
                                ProgressView().controlSize(.small).tint(.white)
                            } else {
                                Image(systemName: "text.viewfinder")
                            }
                            Text(AIL("ai_plan_from_photo"))
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.white.opacity(0.12)))
                    }
                    .disabled(isReadingPhoto)

                    Spacer()
                }

                if let photoError {
                    Text(photoError)
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
            .aiGlowBorder(cornerRadius: 18, active: false)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                readTextFromPhoto(item)
            }

            planWindowCard

            Button {
                inputFocused = false
                speech.stopRecording()
                planner.extract(from: braindump)
            } label: {
                HStack(spacing: 8) {
                    if planner.phase == .extracting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(planner.phase == .extracting ? AIL("ai_plan_sorting") : AIL("ai_plan_sort_button"))
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(AIPalette.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(braindump.trimmingCharacters(in: .whitespaces).isEmpty || planner.isBusy)
            .opacity(braindump.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)

            Button {
                stage = .plan
                planner.buildPlan(includeExistingTodos: true)
            } label: {
                Text(AIL("ai_plan_use_existing"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accent)
            }
            .disabled(planner.isBusy)
        }
    }

    /// Liest den Text aus dem gewählten Bild und hängt ihn an die Eingabe an.
    private func readTextFromPhoto(_ item: PhotosPickerItem) {
        isReadingPhoto = true
        photoError = nil
        Task {
            defer {
                isReadingPhoto = false
                photoItem = nil
            }
            do {
                guard
                    let data = try await item.loadTransferable(type: Data.self),
                    let image = UIImage(data: data)
                else {
                    photoError = AIL("ai_plan_photo_failed")
                    return
                }
                let text = try await AIPhotoToTodos.recognizeText(in: image)
                let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else {
                    photoError = AIL("ai_plan_photo_empty")
                    return
                }
                braindump = braindump.isEmpty ? clean : braindump + "\n" + clean
            } catch {
                photoError = AIL("ai_plan_photo_failed")
            }
        }
    }

    private var recordingLanguage: String {
        switch localizer.currentLanguageCode {
        case "en": return "en-US"
        case "fr": return "fr-FR"
        case "es": return "es-ES"
        default:   return "de-DE"
        }
    }

    private var planWindowCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock")
                .foregroundStyle(accent)
            Text(AIL("ai_plan_window"))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Picker("", selection: $planner.startHour) {
                ForEach(4..<23, id: \.self) { Text("\($0):00").tag($0) }
            }
            .tint(.white)
            Text("–").foregroundStyle(.white.opacity(0.4))
            Picker("", selection: $planner.endHour) {
                ForEach(5..<24, id: \.self) { Text("\($0):00").tag($0) }
            }
            .tint(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }

    // MARK: - Stufe 2: Aufgaben prüfen

    private var reviewStage: some View {
        VStack(spacing: 14) {
            HStack {
                Text(AIL("ai_plan_found", planner.candidates.count))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button(allSelected ? AIL("ai_plan_none") : AIL("ai_plan_all")) {
                    let target = !allSelected
                    for index in planner.candidates.indices {
                        planner.candidates[index].isSelected = target
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(accent)
            }

            ForEach($planner.candidates) { $candidate in
                candidateRow($candidate)
            }

            Toggle(isOn: $includeExisting) {
                Text(AIL("ai_plan_include_existing"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .tint(accent)
            .padding(.top, 2)

            planWindowCard

            VStack(spacing: 10) {
                Button {
                    stage = .plan
                    planner.buildPlan(includeExistingTodos: includeExisting)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                        Text(AIL("ai_plan_build_button"))
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(AIPalette.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(planner.selectedCandidates.isEmpty && !includeExisting)

                Button {
                    let count = planner.applyCandidates()
                    appliedCount = count
                    dismiss()
                } label: {
                    Text(AIL("ai_plan_just_add", planner.selectedCandidates.count))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .disabled(planner.selectedCandidates.isEmpty)
            }
        }
    }

    private var allSelected: Bool {
        !planner.candidates.isEmpty && planner.candidates.allSatisfy(\.isSelected)
    }

    private func candidateRow(_ candidate: Binding<AIPlanner.Candidate>) -> some View {
        let todo = candidate.wrappedValue.todo
        return Button {
            candidate.wrappedValue.isSelected.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: candidate.wrappedValue.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(candidate.wrappedValue.isSelected ? accent : .white.opacity(0.3))

                VStack(alignment: .leading, spacing: 5) {
                    Text(todo.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        priorityChip(todo.priority)
                        if !todo.category.isEmpty {
                            chip(todo.category, color: .white.opacity(0.15))
                        }
                        if let due = todo.mappedDueDate {
                            chip(shortDate(due), color: .white.opacity(0.15))
                        }
                        chip("\(todo.estimatedMinutes) min", color: .white.opacity(0.15))
                    }

                    if !todo.subtasks.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(todo.subtasks, id: \.self) { step in
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.white.opacity(0.35))
                                    Text(step)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(candidate.wrappedValue.isSelected ? 0.08 : 0.04))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stufe 3: Plan

    private var planStage: some View {
        VStack(spacing: 14) {
            if planner.phase == .planning && planner.streamingBlocks.isEmpty {
                AIThinkingIndicator(label: AIL("ai_plan_thinking"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
            }

            if !planner.summary.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(accent)
                    Text(planner.summary)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent.opacity(0.12))
                )
            }

            ForEach(Array(planner.streamingBlocks.enumerated()), id: \.offset) { _, block in
                planBlockRow(block)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: planner.streamingBlocks)

            if let plan = planner.plan, !plan.deferred.isEmpty {
                deferredCard(plan.deferred)
            }

            if planner.phase == .ready, planner.plan != nil {
                Button {
                    let count = planner.applyPlan()
                    appliedCount = count
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(AIL("ai_plan_apply"))
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(AIPalette.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.top, 4)
            }
        }
    }

    private func planBlockRow(_ block: AIPlanBlock) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(block.start)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(block.durationMinutes)′")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(width: 52)

            RoundedRectangle(cornerRadius: 2)
                .fill(kindColor(block.kind))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: kindSymbol(block.kind))
                        .font(.system(size: 11))
                        .foregroundStyle(kindColor(block.kind))
                    Text(block.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                }

                if !block.reason.isEmpty {
                    Text(block.reason)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if block.kind != "break", let quadrant = EisenhowerQuadrant(rawValue: block.quadrant) {
                    HStack(spacing: 6) {
                        chip(quadrant.title, color: quadrant.color.opacity(0.25))
                        priorityChip(block.priority)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.06))
        )
    }

    private func deferredCard(_ titles: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.right")
                    .font(.system(size: 11))
                Text(AIL("ai_plan_deferred_title"))
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.45))

            ForEach(titles, id: \.self) { title in
                Text("• \(title)")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Text(AIL("ai_plan_deferred_hint"))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.04))
        )
    }

    // MARK: - Kleinteile

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color))
    }

    private func priorityChip(_ raw: String) -> some View {
        let priority = TodoPriority(rawValue: raw.lowercased()) ?? .medium
        let color: Color = switch priority {
        case .high:   .red
        case .medium: .orange
        case .low:    .green
        }
        return chip(priority.displayName, color: color.opacity(0.3))
    }

    private func kindColor(_ kind: String) -> Color {
        switch kind {
        case "break": return .green
        case "admin": return .orange
        default:      return accent
        }
    }

    private func kindSymbol(_ kind: String) -> String {
        switch kind {
        case "break": return "cup.and.saucer.fill"
        case "admin": return "tray.full.fill"
        default:      return "brain.head.profile"
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = localizer.currentLocale
        f.dateFormat = "dd.MM."
        return f.string(from: date)
    }
}

//
//  QuickDayPlanSheet.swift
//  BeeFocus_ofc
//
//  Der Tagesplaner für Geräte ohne Apple Intelligence (iOS 18).
//  Gleicher Ablauf wie `AIDayPlanSheet` – Eingabe, Prüfen, Plan –,
//  aber regelbasiert über `QuickDayPlanner` statt über ein Sprachmodell.
//

import PhotosUI
import SwiftUI

struct QuickDayPlanSheet: View {
    /// Vorbelegter Text, z. B. aus dem Brain Dump.
    var initialText: String = ""

    @StateObject private var planner = QuickDayPlanner()
    @ObservedObject private var speech = SpeechManager.shared
    @ObservedObject private var localizer = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @State private var braindump: String = ""
    @State private var includeExisting = true
    @State private var stage: Stage = .input
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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        switch stage {
                        case .input:  inputStage
                        case .review: reviewStage
                        case .plan:   planStage
                        }

                        if let message = planner.errorMessage {
                            AIErrorRow(message: message)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(AIL("ai_plan_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localizer.localizedString(forKey: "brain_close")) {
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
                        }
                        .foregroundStyle(accent)
                    }
                }
                // Im mehrzeiligen Feld legt die Eingabetaste eine neue Zeile an –
                // zum Schließen der Tastatur braucht es diesen Knopf.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(AIL("done")) { inputFocused = false }
                }
            }
            .onAppear {
                speech.requestPermissions()
                if !initialText.isEmpty && braindump.isEmpty {
                    braindump = initialText
                }
            }
            .onDisappear { speech.stopRecording() }
        }
    }

    // MARK: - Stufe 1: Eingabe

    private var inputStage: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    AIBadge(text: AIL("quick_plan_badge"))
                    Spacer()
                }

                Text(AIL("ai_plan_input_title"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Text(AIL("quick_plan_input_subtitle"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)

                // Bewusst ein mitwachsendes TextField statt eines TextEditors:
                // ein TextEditor in einer ScrollView bekommt keine feste Höhe
                // angeboten, fällt dadurch auf Höhe 0 zusammen und lässt sich
                // nicht antippen. Dasselbe Muster nutzt QuickCaptureSheet.
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
                    // Der ganze Kasten soll die Tastatur öffnen, nicht nur die Textzeile.
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

                    // Zettel oder Whiteboard abfotografieren – Vision braucht
                    // kein Apple Intelligence.
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
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                readTextFromPhoto(item)
            }

            planWindowCard

            Button {
                inputFocused = false
                speech.stopRecording()
                planner.extract(from: braindump)
                if !planner.candidates.isEmpty { stage = .review }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                    Text(AIL("ai_plan_sort_button"))
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(AIPalette.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(braindump.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(braindump.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)

            Button {
                planner.reset()
                stage = .plan
                planner.buildPlan(includeExistingTodos: true)
            } label: {
                Text(AIL("ai_plan_use_existing"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accent)
            }
        }
    }

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
                    planner.applyCandidates()
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

    private func candidateRow(_ candidate: Binding<QuickDayPlanner.Candidate>) -> some View {
        let value = candidate.wrappedValue
        return Button {
            candidate.wrappedValue.isSelected.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: value.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(value.isSelected ? accent : .white.opacity(0.3))

                VStack(alignment: .leading, spacing: 5) {
                    Text(value.draft.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        priorityChip(value.draft.priority)
                        if let due = value.draft.dueDate {
                            chip(value.draft.hasTime ? timeText(due) : shortDate(due), color: .white.opacity(0.15))
                        }
                        chip("\(value.estimatedMinutes) min", color: .white.opacity(0.15))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(value.isSelected ? 0.08 : 0.04))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stufe 3: Plan

    private var planStage: some View {
        VStack(spacing: 14) {
            if !planner.summary.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "text.badge.checkmark")
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

            ForEach(planner.blocks) { block in
                planBlockRow(block)
            }

            if !planner.deferred.isEmpty {
                deferredCard(planner.deferred)
            }

            if planner.hasPlan, !planner.blocks.isEmpty {
                Button {
                    planner.applyPlan()
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

    private func planBlockRow(_ block: QuickDayPlanner.Block) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(timeText(block.start))
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

                if !block.note.isEmpty {
                    Text(block.note)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if block.kind != .pause {
                    HStack(spacing: 6) {
                        priorityChip(block.priority)
                        if block.isFixed {
                            chip(AIL("quick_plan_fixed"), color: .white.opacity(0.15))
                        }
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

    private func priorityChip(_ priority: TodoPriority) -> some View {
        let color: Color = switch priority {
        case .high:   .red
        case .medium: .orange
        case .low:    .green
        }
        return chip(priority.displayName, color: color.opacity(0.3))
    }

    private func kindColor(_ kind: QuickDayPlanner.BlockKind) -> Color {
        switch kind {
        case .pause: return .green
        case .admin: return .orange
        case .focus: return accent
        }
    }

    private func kindSymbol(_ kind: QuickDayPlanner.BlockKind) -> String {
        switch kind {
        case .pause: return "cup.and.saucer.fill"
        case .admin: return "tray.full.fill"
        case .focus: return "brain.head.profile"
        }
    }

    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = localizer.currentLocale
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = localizer.currentLocale
        f.dateFormat = "dd.MM."
        return f.string(from: date)
    }
}

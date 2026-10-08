//
//  AITodoAssistSection.swift
//  BeeFocus_ofc
//
//  Die Apple-Intelligence-Sektion in den Aufgaben-Formularen:
//  ordnet automatisch ein und schlägt Schritte vor.
//

import SwiftUI

@available(iOS 26.0, *)
struct AITodoAssistSection: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var category: Category?
    @Binding var priority: TodoPriority
    @Binding var subTasks: [SubTask]
    /// Optional: Wird eine Fälligkeit mitgegeben, darf das Verfassen auch
    /// das erkannte Datum übernehmen.
    var dueDate: Binding<Date>? = nil
    var hasDueDate: Binding<Bool>? = nil

    @EnvironmentObject private var todoStore: TodoStore
    @ObservedObject private var availability = AIAvailability.shared
    @ObservedObject private var localizer = LocalizationManager.shared

    @AppStorage("aiAutoClassify") private var autoClassify: Bool = true

    @State private var suggestion: AITodoClassification?
    @State private var composed: QuickTodoDraft?
    @State private var isComposing = false
    @State private var composeTask: Task<Void, Never>?
    @State private var isClassifying = false
    @State private var errorMessage: String?
    @State private var showSubtaskSheet = false
    @State private var classifyTask: Task<Void, Never>?
    /// Titel, für den bereits ein Vorschlag geholt wurde – verhindert Mehrfachanfragen.
    @State private var lastClassifiedTitle = ""

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        if availability.isAvailable {
            Section {
                if let suggestion {
                    suggestionRow(suggestion)
                } else if isClassifying {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text(localizer.localizedString(forKey: "ai_classify_thinking"))
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        classify(force: true)
                    } label: {
                        Label(localizer.localizedString(forKey: "ai_classify_button"), systemImage: "wand.and.sparkles")
                    }
                    .disabled(trimmedTitle.count < 3)
                }

                if let composed {
                    composedRow(composed)
                } else if isComposing {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text(localizer.localizedString(forKey: "ai_compose_thinking"))
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        compose()
                    } label: {
                        Label(
                            localizer.localizedString(forKey: "ai_compose_button"),
                            systemImage: "text.badge.star"
                        )
                    }
                    .disabled(trimmedTitle.count < 6)
                }

                Button {
                    showSubtaskSheet = true
                } label: {
                    Label(localizer.localizedString(forKey: "ai_subtasks_button"), systemImage: "list.bullet.indent")
                }
                .disabled(trimmedTitle.count < 3)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                }
            } header: {
                HStack(spacing: 6) {
                    Text(localizer.localizedString(forKey: "ai_settings_title"))
                    AIBadge(text: nil)
                }
            } footer: {
                Text(localizer.localizedString(forKey: "ai_settings_privacy"))
                    .font(.system(size: 11))
            }
            .onChange(of: title) { _, _ in
                // Vorschläge verwerfen, sobald der Titel sich ändert.
                suggestion = nil
                composed = nil
                errorMessage = nil
                if autoClassify { classifyDebounced() }
            }
            .onDisappear {
                classifyTask?.cancel()
                composeTask?.cancel()
            }
            .sheet(isPresented: $showSubtaskSheet) {
                AISubtaskSheet(todoTitle: trimmedTitle, todoDetails: description) { steps in
                    let existing = Set(subTasks.map(\.title))
                    for step in steps where !existing.contains(step) {
                        subTasks.append(SubTask(title: step))
                    }
                }
            }
        }
    }

    // MARK: - Vorschlagszeile

    private func suggestionRow(_ suggestion: AITodoClassification) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(AIPalette.colors[0])
                Text(localizer.localizedString(forKey: "ai_classify_suggestion"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                if !suggestion.category.isEmpty {
                    detailLine(
                        label: localizer.localizedString(forKey: "category"),
                        value: suggestion.category
                    )
                }
                detailLine(
                    label: localizer.localizedString(forKey: "priority"),
                    value: suggestion.mappedPriority.displayName
                )
                if let quadrant = EisenhowerQuadrant(rawValue: suggestion.quadrant) {
                    detailLine(label: "Eisenhower", value: quadrant.title)
                }
                detailLine(label: "Dauer", value: "\(suggestion.estimatedMinutes) min")
            }

            HStack(spacing: 10) {
                Button {
                    apply(suggestion)
                } label: {
                    Text(localizer.localizedString(forKey: "ai_classify_accept"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    withAnimation { self.suggestion = nil }
                } label: {
                    Text(localizer.localizedString(forKey: "ai_classify_dismiss"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func detailLine(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
    }

    // MARK: - Verfassen

    /// Zeigt, was Apple Intelligence aus der Eingabe gemacht hat, bevor etwas
    /// überschrieben wird: ein Titel, der Rest als Beschreibung, Aufzählungen
    /// als Unteraufgaben.
    private func composedRow(_ draft: QuickTodoDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "text.badge.star")
                    .font(.system(size: 11))
                    .foregroundStyle(AIPalette.colors[0])
                Text(localizer.localizedString(forKey: "ai_compose_suggestion"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(draft.title)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            if !draft.details.isEmpty {
                Text(draft.details)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !draft.subtasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(draft.subtasks, id: \.self) { item in
                        HStack(spacing: 7) {
                            Image(systemName: "circle")
                                .font(.system(size: 8))
                                .foregroundStyle(AIPalette.colors[0].opacity(0.7))
                            Text(item).font(.system(size: 13))
                            Spacer()
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    applyComposed(draft)
                } label: {
                    Text(localizer.localizedString(forKey: "ai_classify_accept"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    withAnimation { composed = nil }
                } label: {
                    Text(localizer.localizedString(forKey: "ai_classify_dismiss"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func compose() {
        composeTask?.cancel()
        // Beschreibung mitgeben: Steht dort schon etwas, gehört es zur Aufgabe.
        let input = [trimmedTitle, description.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard input.count >= 6 else { return }

        composeTask = Task {
            isComposing = true
            errorMessage = nil
            defer { isComposing = false }
            do {
                let draft = try await AITodoIntelligence.shared.compose(from: input)
                guard !Task.isCancelled else { return }
                withAnimation { composed = draft }
            } catch is CancellationError {
                return
            } catch {
                errorMessage = AIErrorText.describe(error)
            }
        }
    }

    /// Übernimmt den Entwurf in die Formularfelder. Vorhandene Eingaben gehen
    /// dabei nicht verloren: Die Beschreibung wird ergänzt, Unteraufgaben
    /// werden angehängt.
    private func applyComposed(_ draft: QuickTodoDraft) {
        if !draft.title.isEmpty { title = draft.title }

        if !draft.details.isEmpty {
            let existing = description.trimmingCharacters(in: .whitespacesAndNewlines)
            if existing.isEmpty {
                description = draft.details
            } else if !existing.localizedCaseInsensitiveContains(draft.details) {
                description = existing + "\n" + draft.details
            }
        }

        let known = Set(subTasks.map { QuickTodoDraft.normalizedKey($0.title) })
        for item in draft.subtasks where !known.contains(QuickTodoDraft.normalizedKey(item)) {
            subTasks.append(SubTask(title: item))
        }

        priority = draft.priority
        if !draft.categoryName.isEmpty,
           let match = todoStore.categories.first(where: {
               $0.name.localizedCaseInsensitiveCompare(draft.categoryName) == .orderedSame
           }) {
            category = match
        }

        if let due = draft.dueDate, let dateBinding = dueDate {
            dateBinding.wrappedValue = due
            hasDueDate?.wrappedValue = true
        }

        withAnimation {
            composed = nil
            suggestion = nil
        }
        // Der Titel hat sich geändert – ein alter Einordnungsvorschlag passt nicht mehr.
        lastClassifiedTitle = ""
    }

    // MARK: - Ablauf

    /// Wartet kurz, bis der Nutzer mit dem Tippen fertig ist.
    private func classifyDebounced() {
        classifyTask?.cancel()
        let current = trimmedTitle
        guard current.count >= 5, current != lastClassifiedTitle else { return }

        classifyTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, trimmedTitle == current else { return }
            await runClassification(for: current)
        }
    }

    private func classify(force: Bool) {
        classifyTask?.cancel()
        let current = trimmedTitle
        guard current.count >= 3 else { return }
        classifyTask = Task { await runClassification(for: current) }
    }

    private func runClassification(for text: String) async {
        isClassifying = true
        errorMessage = nil
        defer { isClassifying = false }

        do {
            let result = try await AITodoIntelligence.shared.classify(title: text)
            guard !Task.isCancelled else { return }
            lastClassifiedTitle = text
            withAnimation { suggestion = result }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = AIErrorText.describe(error)
        }
    }

    /// Übernimmt den Vorschlag in die Formularfelder.
    private func apply(_ suggestion: AITodoClassification) {
        if let match = todoStore.categories.first(where: {
            $0.name.localizedCaseInsensitiveCompare(suggestion.category) == .orderedSame
        }) {
            category = match
        }
        priority = suggestion.mappedPriority
        withAnimation { self.suggestion = nil }
    }
}

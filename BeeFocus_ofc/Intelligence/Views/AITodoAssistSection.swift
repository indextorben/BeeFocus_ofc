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

    @EnvironmentObject private var todoStore: TodoStore
    @ObservedObject private var availability = AIAvailability.shared
    @ObservedObject private var localizer = LocalizationManager.shared

    @AppStorage("aiAutoClassify") private var autoClassify: Bool = true

    @State private var suggestion: AITodoClassification?
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
                // Vorschlag verwerfen, sobald der Titel sich ändert.
                suggestion = nil
                errorMessage = nil
                if autoClassify { classifyDebounced() }
            }
            .onDisappear { classifyTask?.cancel() }
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

//
//  AISubtaskSheet.swift
//  BeeFocus_ofc
//
//  Zerlegt eine Aufgabe auf Knopfdruck in Schritte. Die Vorschläge trudeln
//  einzeln ein, der Nutzer wählt aus, was übernommen wird.
//

import SwiftUI

@available(iOS 26.0, *)
struct AISubtaskSheet: View {
    let todoTitle: String
    let todoDetails: String
    /// Wird mit den ausgewählten Schritten aufgerufen.
    let onApply: ([String]) -> Void

    @ObservedObject private var availability = AIAvailability.shared
    @ObservedObject private var localizer = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @State private var suggestions: [Suggestion] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var task: Task<Void, Never>?

    private struct Suggestion: Identifiable, Equatable {
        let id = UUID()
        let title: String
        var isSelected: Bool = true
    }

    private var accent: Color { AIAccent.color(for: aktivesThema) }
    private var selected: [String] { suggestions.filter(\.isSelected).map(\.title) }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView().ignoresSafeArea()

                if availability.isAvailable {
                    content
                } else {
                    ScrollView { AIUnavailableCard().padding(20) }
                }
            }
            .navigationTitle(AIL("ai_subtasks_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localizer.localizedString(forKey: "brain_close")) {
                        task?.cancel()
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        generate()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(accent)
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                availability.refresh()
                if suggestions.isEmpty { generate() }
            }
            .onDisappear { task?.cancel() }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack(alignment: .top, spacing: 10) {
                        AIBadge(text: nil)
                        Text(todoTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.06))
                    )

                    if let errorMessage {
                        AIErrorRow(message: errorMessage) { generate() }
                    }

                    if isLoading && suggestions.isEmpty {
                        AIThinkingIndicator(label: AIL("ai_subtasks_thinking"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 24)
                    }

                    ForEach($suggestions) { $suggestion in
                        Button {
                            $suggestion.wrappedValue.isSelected.toggle()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: suggestion.isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 19))
                                    .foregroundStyle(suggestion.isSelected ? accent : .white.opacity(0.3))
                                Text(suggestion.title)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(.white.opacity(suggestion.isSelected ? 0.08 : 0.04))
                            )
                        }
                        .buttonStyle(.plain)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: suggestions)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }

            if !suggestions.isEmpty {
                Button {
                    onApply(selected)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text(AIL("ai_subtasks_apply", selected.count))
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(AIPalette.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(selected.isEmpty)
                .opacity(selected.isEmpty ? 0.45 : 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
    }

    private func generate() {
        task?.cancel()
        suggestions = []
        errorMessage = nil
        isLoading = true

        task = Task {
            do {
                let stream = AITodoIntelligence.shared.streamSubtasks(for: todoTitle, details: todoDetails)
                for try await items in stream {
                    if Task.isCancelled { return }
                    // Nur neu hinzugekommene Schritte anhängen, damit die
                    // Auswahl des Nutzers erhalten bleibt.
                    if items.count > suggestions.count {
                        let existing = Set(suggestions.map(\.title))
                        for title in items where !existing.contains(title) {
                            suggestions.append(Suggestion(title: title))
                        }
                    }
                }
                isLoading = false
                if suggestions.isEmpty {
                    errorMessage = AIL("ai_subtasks_empty")
                }
            } catch is CancellationError {
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = AIErrorText.describe(error)
            }
        }
    }
}

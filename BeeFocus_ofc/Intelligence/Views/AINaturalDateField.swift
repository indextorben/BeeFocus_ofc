//
//  AINaturalDateField.swift
//  BeeFocus_ofc
//
//  Datumseingabe in normaler Sprache: "nächsten Dienstag früh", "in drei
//  Tagen", "übermorgen 15 Uhr". Wird zu einem echten Datum aufgelöst.
//

import SwiftUI

@available(iOS 26.0, *)
struct AINaturalDateField: View {
    @Binding var date: Date
    @Binding var hasDate: Bool

    @ObservedObject private var localizer = LocalizationManager.shared
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var text = ""
    @State private var isResolving = false
    @State private var failed = false
    @FocusState private var focused: Bool

    private var accent: Color { AIAccent.color(for: aktivesThema) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 13))
                    .foregroundStyle(accent)

                TextField(localizer.localizedString(forKey: "ai_date_placeholder"), text: $text)
                    .font(.system(size: 15))
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(resolve)

                if isResolving {
                    ProgressView().controlSize(.small)
                } else if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button(action: resolve) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            if failed {
                Text(localizer.localizedString(forKey: "ai_date_failed"))
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func resolve() {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isResolving = true
        failed = false
        focused = false

        Task {
            defer { isResolving = false }
            if let resolved = await AITodoIntelligence.shared.parseDate(from: query) {
                withAnimation {
                    date = resolved
                    hasDate = true
                    text = ""
                }
            } else {
                failed = true
            }
        }
    }
}

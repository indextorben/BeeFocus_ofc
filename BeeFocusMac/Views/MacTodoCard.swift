import SwiftUI

struct MacTodoCard: View {
    let todo: MacTodoItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onToggleFavorite: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("aktivePriorityStyle") private var aktivePriorityStyle: String = "standard"
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @State private var isHovered = false

    private var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    private var priorityColor: Color {
        switch todo.priority {
        case .low:    return .green
        case .medium: return .orange
        case .high:   return .red
        }
    }

    private var priorityLabel: String {
        switch todo.priority {
        case .low:    return aktivePriorityStyle == "emoji" ? "🟢 Niedrig"  : "Niedrig"
        case .medium: return aktivePriorityStyle == "emoji" ? "🟡 Mittel"   : "Mittel"
        case .high:   return aktivePriorityStyle == "emoji" ? "🔴 Hoch"     : "Hoch"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Checkbox
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(todo.isCompleted ? priorityColor : .clear)
                        .frame(width: 22, height: 22)
                    Circle()
                        .stroke(priorityColor.opacity(todo.isCompleted ? 1 : 0.5), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if todo.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 5) {
                Text(todo.title)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough(todo.isCompleted, color: .secondary)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                if !todo.description.isEmpty {
                    Text(todo.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(priorityColor)
                            .frame(width: 6, height: 6)
                        Text(priorityLabel)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    if let due = todo.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(dueDateLabel(due))
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(todo.isOverdue ? .red : .secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            // Actions
            HStack(spacing: 2) {
                if isHovered {
                    Group {
                        actionButton(icon: todo.isFavorite ? "star.fill" : "star",
                                     color: todo.isFavorite ? .yellow : .secondary,
                                     action: onToggleFavorite)
                        actionButton(icon: "pencil", color: .secondary, action: onEdit)
                        actionButton(icon: "trash", color: .red, action: onDelete)
                    }
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                } else if todo.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isHovered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .themeGlass(cornerRadius: 12)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [themeC1.opacity(todo.isCompleted ? 0.3 : 0.9),
                                 themeC2.opacity(todo.isCompleted ? 0.2 : 0.6)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .padding(.vertical, 10)
        }
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .opacity(todo.isCompleted ? 0.6 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture { if !todo.isCompleted { onEdit() } }
    }

    @ViewBuilder
    private func actionButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color.opacity(0.8))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dueDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Heute" }
        if cal.isDateInTomorrow(date)  { return "Morgen" }
        if cal.isDateInYesterday(date) { return "Gestern" }
        let f = DateFormatter(); f.dateFormat = "d. MMM"; f.locale = Locale(identifier: "de_DE")
        return f.string(from: date)
    }
}

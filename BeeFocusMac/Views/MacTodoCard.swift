import SwiftUI

struct MacTodoCard: View {
    let todo: MacTodoItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.activeTheme) private var activeTheme
    @AppStorage("aktivePriorityStyle") private var aktivePriorityStyle: String = "standard"
    @State private var isHovered = false

    private var isDark: Bool { colorScheme == .dark }

    private var priorityColor: Color {
        switch todo.priority {
        case .low:    return .green
        case .medium: return .orange
        case .high:   return .red
        }
    }

    private var cardGradient: LinearGradient {
        switch todo.priority {
        case .low:
            return LinearGradient(colors: [.green.opacity(isDark ? 0.15 : 0.08),
                                           .green.opacity(isDark ? 0.28 : 0.18)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .medium:
            return LinearGradient(colors: [.orange.opacity(isDark ? 0.12 : 0.07),
                                           .orange.opacity(isDark ? 0.28 : 0.20)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .high:
            return LinearGradient(colors: [.red.opacity(isDark ? 0.15 : 0.09),
                                           .red.opacity(isDark ? 0.32 : 0.24)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
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
        ZStack(alignment: .topTrailing) {
            // Theme card decoration (Ozean, Wald, Nacht, …)
            TaskCardThemeDecoration(theme: activeTheme, isDark: isDark, isActive: false)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack(alignment: .center, spacing: 12) {
                // Checkbox
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .fill(todo.isCompleted ? priorityColor : Color.clear)
                            .frame(width: 28, height: 28)
                        Circle()
                            .stroke(priorityColor, lineWidth: 2)
                            .frame(width: 28, height: 28)
                        if todo.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Content
                VStack(alignment: .leading, spacing: 5) {
                    Text(todo.title)
                        .font(.system(size: 15, weight: .semibold))
                        .strikethrough(todo.isCompleted, color: .secondary)
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                        .lineLimit(2)

                    if !todo.description.isEmpty {
                        Text(todo.description)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        // Priority badge
                        Text(priorityLabel)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(priorityColor.opacity(0.15)))
                            .foregroundStyle(priorityColor)
                            .overlay(Capsule().stroke(priorityColor.opacity(0.3), lineWidth: 1))

                        if let due = todo.dueDate {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(dueDateLabel(due))
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(todo.isOverdue ? .red : .secondary)
                        }

                        if todo.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                Spacer()

                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(.red.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .background(cardGradient, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(priorityColor.opacity(isDark ? 0.25 : 0.18), lineWidth: 1)
        )
        .shadow(color: priorityColor.opacity(isDark ? 0.28 : 0.18),
                radius: isHovered ? 14 : 7, x: 0, y: isHovered ? 7 : 3)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
        .opacity(todo.isCompleted ? 0.65 : 1.0)
    }

    private func dueDateLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date)    { return "Heute" }
        if Calendar.current.isDateInTomorrow(date) { return "Morgen" }
        let f = DateFormatter(); f.dateFormat = "d. MMM"; f.locale = Locale(identifier: "de_DE")
        return f.string(from: date)
    }
}

import Foundation
import SwiftUI
import SwiftData

// MARK: - Priority Badge

struct PriorityBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.28), lineWidth: 1))
    }
}

// MARK: - TodoCard

struct TodoCard: View {
    @Binding var todo: TodoItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onShare: (() -> Void)?
    let onMoveToFolder: (() -> Void)?
    let showCategory: Bool

    init(
        todo: Binding<TodoItem>,
        showCategory: Bool = false,
        onToggle: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onShare: (() -> Void)? = nil,
        onMoveToFolder: (() -> Void)? = nil
    ) {
        self._todo = todo
        self.showCategory = showCategory
        self.onToggle = onToggle
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onShare = onShare
        self.onMoveToFolder = onMoveToFolder
    }

    @State private var showingSubTasks = false
    @State private var showingImages = false
    @State private var isPressed = false
    @State private var appeared = false
    @State private var images: [Data] = []

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var localizer = LocalizationManager.shared
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("aktivePriorityStyle")   private var aktivePriorityStyle: String = "standard"

    // MARK: - Computed

    private var isDark: Bool { colorScheme == .dark }

    private var priorityColor: Color {
        switch todo.priority {
        case .low:    return .green
        case .medium: return .orange
        case .high:   return .red
        }
    }

    private var priorityText: String {
        if aktivePriorityStyle == "emoji" {
            switch todo.priority {
            case .low:    return "🟢 " + localizer.localizedString(forKey: "priority_low")
            case .medium: return "🟡 " + localizer.localizedString(forKey: "priority_medium")
            case .high:   return "🔴 " + localizer.localizedString(forKey: "priority_high")
            }
        }
        switch todo.priority {
        case .low:    return localizer.localizedString(forKey: "priority_low")
        case .medium: return localizer.localizedString(forKey: "priority_medium")
        case .high:   return localizer.localizedString(forKey: "priority_high")
        }
    }

    // Accent: überfällig → rot | aktiv (läuft) → grün | hat Datum → blau | sonst → Priorität
    private var cardAccent: Color {
        guard !todo.isCompleted else { return .secondary }
        if todo.isOverdue      { return .red }
        if todo.isActive       { return Color(red: 0.15, green: 0.75, blue: 0.45) }
        if todo.dueDate != nil { return Color(red: 0.25, green: 0.55, blue: 1.0) }
        return priorityColor
    }

    private var cardTintOpacity: Double { isDark ? 0.12 : 0.07 }

    private var cardBorderOpacity: Double { isDark ? 0.38 : 0.22 }

    private var hasInfoRow: Bool {
        todo.dueDate != nil
        || (showCategory && todo.category?.name.isEmpty == false)
        || !todo.subTasks.isEmpty
        || !todo.imageDataArray.isEmpty
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(cardAccent)
                .frame(width: 4)
                .padding(.vertical, 10)
                .padding(.leading, 10)
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: todo.isOverdue)
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: todo.dueDate != nil)

            VStack(alignment: .leading, spacing: 0) {
                // Top row: checkmark + title + menu
                HStack(alignment: .top, spacing: 11) {
                    checkmarkButton

                    VStack(alignment: .leading, spacing: 4) {
                        Text(todo.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                todo.isCompleted
                                    ? AnyShapeStyle(.secondary)
                                    : AnyShapeStyle(isDark ? Color.white.opacity(0.92) : Color.primary)
                            )
                            .strikethrough(todo.isCompleted, color: .secondary)
                            .animation(.easeInOut(duration: 0.2), value: todo.isCompleted)

                        if !todo.description.isEmpty {
                            Text(todo.description)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .strikethrough(todo.isCompleted, color: .secondary)
                                .lineLimit(2)
                                .animation(.easeInOut(duration: 0.2), value: todo.isCompleted)
                        }
                    }

                    Spacer(minLength: 4)

                    menuButton
                }
                .padding(.top, 13)
                .padding(.horizontal, 12)

                // Info row
                if hasInfoRow {
                    infoRow
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                }

                // Bottom: priority badge
                HStack {
                    Spacer()
                    PriorityBadge(text: priorityText, color: priorityColor)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 11)
            }
        }
        // Glass background
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardAccent.opacity(cardTintOpacity))
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: cardAccent)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardAccent.opacity(cardBorderOpacity), lineWidth: 1)
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: cardAccent)
        )
        .shadow(color: cardAccent.opacity(isDark ? 0.18 : 0.10), radius: 8, x: 0, y: 3)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // Press
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .opacity(isPressed ? 0.92 : (todo.isCompleted ? 0.65 : 1.0))
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isPressed)
        .animation(.easeInOut(duration: 0.25), value: todo.isCompleted)
        // Entrance
        .opacity(appeared ? (todo.isCompleted ? 0.65 : 1.0) : 0)
        .offset(y: appeared ? 0 : 18)
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: appeared)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.04)) {
                appeared = true
            }
        }
        // Tap for press flash
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.12)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.easeInOut(duration: 0.12)) { isPressed = false }
            }
        }
        // Context menu (long press)
        .contextMenu {
            contextMenuItems
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 0.92).combined(with: .opacity)
        ))
        .padding(.vertical, 3)
        .sheet(isPresented: $showingSubTasks) { SubTasksView(todo: todo) }
        .sheet(isPresented: $showingImages) { ImagesView(images: $images) }
    }

    // MARK: - Checkmark

    private var checkmarkButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                onToggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(todo.isCompleted ? .green.opacity(0.15) : .clear)
                    .frame(width: 30, height: 30)
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(todo.isCompleted ? .green : .secondary.opacity(0.6))
                    .scaleEffect(todo.isCompleted ? 1.08 : 1.0)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: todo.isCompleted)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ellipsis Menu

    private var menuButton: some View {
        Menu {
            contextMenuItems
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.secondary.opacity(isDark ? 0.15 : 0.10), in: Circle())
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Info Row

    private var infoRow: some View {
        HStack(spacing: 6) {
            // Due date / status badge
            if todo.dueDate != nil && !todo.isCompleted {
                if todo.isActive {
                    // Zeitraum läuft gerade
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(red: 0.15, green: 0.75, blue: 0.45))
                            .frame(width: 6, height: 6)
                        Text("Running")
                            .fontWeight(.bold)
                        if let remaining = todo.remainingTimeString {
                            Text("· \(remaining)")
                                .fontWeight(.medium)
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(red: 0.15, green: 0.75, blue: 0.45), in: Capsule())
                } else if todo.isOverdue {
                    Label("Overdue", systemImage: "exclamationmark.clock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.red, in: Capsule())
                } else if let due = todo.dueDate {
                    // Geplant, noch nicht fällig
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text(due, style: .date)
                        Text(due, style: .time)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 0.25, green: 0.55, blue: 1.0))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(red: 0.25, green: 0.55, blue: 1.0).opacity(isDark ? 0.18 : 0.10), in: Capsule())
                }
            }

            // Category
            if showCategory, let cat = todo.category?.name, !cat.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 9))
                    Text(cat)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(.secondary.opacity(0.10), in: Capsule())
            }

            Spacer(minLength: 0)

            // Subtasks
            if !todo.subTasks.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        showingSubTasks = true
                    }
                } label: {
                    let done = todo.subTasks.filter(\.isCompleted).count
                    HStack(spacing: 3) {
                        Image(systemName: "checklist")
                            .font(.system(size: 10))
                        Text("\(done)/\(todo.subTasks.count)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(cardAccent)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(cardAccent.opacity(isDark ? 0.18 : 0.10), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            // Images
            if !todo.imageDataArray.isEmpty {
                Button {
                    images = todo.imageDataArray
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        showingImages = true
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 10))
                        Text("\(todo.imageDataArray.count)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(.secondary.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 2)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button { onEdit() } label: {
            Label(localizer.localizedString(forKey: "Bearbeiten"), systemImage: "pencil")
        }
        if let onShare {
            Button { onShare() } label: {
                Label(localizer.localizedString(forKey: "Teilen"), systemImage: "square.and.arrow.up")
            }
        }
        if let onMoveToFolder {
            Button { onMoveToFolder() } label: {
                Label("In Ordner verschieben", systemImage: "folder.badge.plus")
            }
        }
        Divider()
        Button(role: .destructive) { onDelete() } label: {
            Label(localizer.localizedString(forKey: "Löschen"), systemImage: "trash")
        }
    }
}

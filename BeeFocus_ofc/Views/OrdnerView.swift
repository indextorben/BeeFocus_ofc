import SwiftUI

struct OrdnerView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @ObservedObject private var localizer = LocalizationManager.shared

    @State private var showingAddAlert = false
    @State private var newFolderName = ""
    @State private var folderToDelete: String? = nil
    @State private var showDeleteConfirm = false
    @State private var appeared = false

    private var isDark: Bool { colorScheme == .dark }
    private var c1: Color { appThemaFarben(aktivesThema).0 }
    private var c2: Color { appThemaFarben(aktivesThema).1 }
    private var accent: Color { aktivesThema.isEmpty ? Color.indigo : c1 }

    private let standardFolders: [(id: String, locKey: String, icon: String, color: Color)] = [
        ("Today",               "folder_today",     "sun.max.fill",                   .orange),
        ("Overdue",             "folder_overdue",   "exclamationmark.circle.fill",    .red),
        ("This Week",           "folder_this_week", "calendar.badge.clock",           .blue),
        ("This Month",          "folder_this_month","calendar",                       .purple),
        ("Later",               "folder_later",     "arrow.forward.circle.fill",      .teal),
        ("General",             "folder_general",   "tray.fill",                      Color(.systemGray)),
        ("Birthdays & Holidays","folder_birthdays", "calendar.badge.exclamationmark", .pink),
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    sectionCard(
                        icon: "folder.fill",
                        title: localizer.localizedString(forKey: "folder_default_folders"),
                        color: accent,
                        sectionIndex: 0
                    ) {
                        ForEach(Array(standardFolders.enumerated()), id: \.offset) { i, folder in
                            if i > 0 { rowDivider() }
                            standardFolderRow(folder)
                        }
                    }

                    sectionCard(
                        icon: "folder.badge.plus",
                        title: localizer.localizedString(forKey: "folder_custom_folders"),
                        color: accent,
                        sectionIndex: 1
                    ) {
                        if todoStore.customFolders.isEmpty {
                            emptyCustomState
                        } else {
                            ForEach(Array(todoStore.customFolders.enumerated()), id: \.offset) { i, folder in
                                if i > 0 { rowDivider() }
                                customFolderRow(folder)
                            }
                        }
                    }

                    Text(localizer.localizedString(forKey: "folder_hint"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut.delay(0.35), value: appeared)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 48)
            }
        }
        .navigationTitle(localizer.localizedString(forKey: "folder_nav_title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    newFolderName = ""
                    showingAddAlert = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 34, height: 34)
                        .background(accent.opacity(0.12), in: Circle())
                }
            }
        }
        .alert(localizer.localizedString(forKey: "folder_new_alert_title"), isPresented: $showingAddAlert) {
            TextField(localizer.localizedString(forKey: "folder_name_placeholder"), text: $newFolderName)
            Button(localizer.localizedString(forKey: "folder_create")) {
                let name = newFolderName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                todoStore.addCustomFolder(name)
            }
            Button(localizer.localizedString(forKey: "cancel"), role: .cancel) {}
        } message: {
            Text(localizer.localizedString(forKey: "folder_new_alert_msg"))
        }
        .confirmationDialog(localizer.localizedString(forKey: "folder_delete_title"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(localizer.localizedString(forKey: "cal_del_confirm_delete"), role: .destructive) {
                if let f = folderToDelete { todoStore.removeCustomFolder(f) }
            }
            Button(localizer.localizedString(forKey: "cancel"), role: .cancel) {}
        } message: {
            Text(localizer.localizedString(forKey: "folder_delete_msg"))
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.05)) {
                appeared = true
            }
        }
    }

    // MARK: - Standard Folder Row

    private func standardFolderRow(_ folder: (id: String, locKey: String, icon: String, color: Color)) -> some View {
        HStack(spacing: 14) {
            iconBadge(icon: folder.icon, color: folder.color)

            Text(localizer.localizedString(forKey: folder.locKey))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)

            Spacer()

            let count = taskCount(for: folder.id)
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(folder.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(folder.color.opacity(isDark ? 0.22 : 0.12), in: Capsule())
            }

            Image(systemName: "lock.fill")
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Custom Folder Row

    private func customFolderRow(_ folder: String) -> some View {
        HStack(spacing: 14) {
            iconBadge(icon: "folder.fill", color: accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)

                let count = todoStore.todos.filter { $0.customFolder == folder }.count
                Text(count == 0
                     ? localizer.localizedString(forKey: "folder_empty")
                     : String(format: localizer.localizedString(forKey: "folder_task_count"), count))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            let count = todoStore.todos.filter { $0.customFolder == folder }.count
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accent.opacity(isDark ? 0.22 : 0.12), in: Capsule())
            }

            Button {
                folderToDelete = folder
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.red.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(.red.opacity(isDark ? 0.14 : 0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Empty State

    private var emptyCustomState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(accent.opacity(0.5))
            Text(localizer.localizedString(forKey: "folder_no_custom"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
            Text(localizer.localizedString(forKey: "folder_no_custom_hint"))
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
    }

    // MARK: - Section Card

    @ViewBuilder
    private func sectionCard<Content: View>(
        icon: String,
        title: String,
        color: Color,
        sectionIndex: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let delay = 0.10 + Double(sectionIndex) * 0.08
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(aktivesThema.isEmpty ? color : c1.opacity(0.85))
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(aktivesThema.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(c1.opacity(0.5)))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                content()
            }
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [c1.opacity(isDark ? 0.14 : 0.09),
                                 c2.opacity(isDark ? 0.07 : 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .opacity(aktivesThema.isEmpty ? 0 : 1)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: aktivesThema.isEmpty
                                ? [Color.white.opacity(isDark ? 0.12 : 0.60),
                                   Color.white.opacity(isDark ? 0.04 : 0.20)]
                                : [c1.opacity(isDark ? 0.50 : 0.32),
                                   c2.opacity(isDark ? 0.22 : 0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(isDark ? 0.22 : 0.07), radius: 14, x: 0, y: 5)
            .shadow(color: c1.opacity(isDark ? 0.18 : 0.08), radius: 18, x: 0, y: 2)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 28)
        .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(delay), value: appeared)
    }

    // MARK: - Helpers

    private func iconBadge(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .shadow(color: color.opacity(0.35), radius: 4, x: 0, y: 2)
    }

    private func rowDivider() -> some View {
        Divider()
            .padding(.leading, 66)
            .opacity(0.4)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            if isDark {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.06, blue: 0.14),
                             Color(red: 0.10, green: 0.08, blue: 0.20),
                             Color(red: 0.08, green: 0.06, blue: 0.16)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [Color(red: 0.94, green: 0.92, blue: 1.0),
                             Color(red: 0.97, green: 0.95, blue: 1.0),
                             Color(red: 0.92, green: 0.96, blue: 1.0)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
            Circle()
                .fill(RadialGradient(
                    colors: [c1.opacity(isDark ? 0.20 : 0.13), .clear],
                    center: .center, startRadius: 0, endRadius: 220
                ))
                .frame(width: 440, height: 440)
                .offset(x: -80, y: -100)
                .blur(radius: 30)
            Circle()
                .fill(RadialGradient(
                    colors: [c2.opacity(isDark ? 0.13 : 0.09), .clear],
                    center: .center, startRadius: 0, endRadius: 180
                ))
                .frame(width: 320, height: 320)
                .offset(x: 140, y: 250)
                .blur(radius: 25)
        }
        .animation(.easeInOut(duration: 0.6), value: aktivesThema)
    }

    // MARK: - Task Count

    private func taskCount(for title: String) -> Int {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let endOfToday   = cal.date(bySettingHour: 23, minute: 59, second: 59, of: startOfToday) ?? now
        let endOfWeek    = cal.date(byAdding: .day, value: 6, to: endOfToday) ?? now
        let endOfMonth   = cal.date(byAdding: .day, value: 29, to: endOfToday) ?? now

        switch title {
        case "Today":
            return todoStore.todos.filter {
                guard let d = $0.dueDate else { return false }
                return !$0.isCompleted && d >= startOfToday && d <= endOfToday
            }.count
        case "Overdue":
            return todoStore.todos.filter {
                guard let d = $0.dueDate else { return false }
                return !$0.isCompleted && d < startOfToday
            }.count
        case "This Week":
            return todoStore.todos.filter {
                guard let d = $0.dueDate else { return false }
                return d > endOfToday && d <= endOfWeek
            }.count
        case "This Month":
            return todoStore.todos.filter {
                guard let d = $0.dueDate else { return false }
                return d > endOfWeek && d <= endOfMonth
            }.count
        case "Later":
            return todoStore.todos.filter {
                guard let d = $0.dueDate else { return false }
                return d > endOfMonth
            }.count
        case "General":
            return todoStore.todos.filter { $0.dueDate == nil && $0.customFolder == nil }.count
        case "Birthdays & Holidays":
            let keywords = ["geburtstag", "birthday", "feiertag", "holiday"]
            return todoStore.todos.filter { todo in
                if let catName = todo.category?.name.lowercased(),
                   keywords.contains(where: { catName.contains($0) }) { return true }
                return keywords.contains(where: { todo.title.lowercased().hasPrefix($0) })
            }.count
        default: return 0
        }
    }
}

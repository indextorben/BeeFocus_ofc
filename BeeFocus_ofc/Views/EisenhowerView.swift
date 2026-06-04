import SwiftUI

struct EisenhowerView: View {
    @ObservedObject private var eisStore = EisenhowerStore.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @EnvironmentObject var todoStore: TodoStore

    @State private var assignSheet: TodoItem? = nil
    @State private var selectedQuadrant: EisenhowerQuadrant? = nil

    private var accent: Color {
        aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : appThemaFarben(aktivesThema).0
    }

    private var uncompletedTodos: [TodoItem] {
        todoStore.todos.filter { !$0.isCompleted }
    }

    private func todos(in q: EisenhowerQuadrant) -> [TodoItem] {
        uncompletedTodos.filter { eisStore.quadrant(of: $0.id) == q }
    }

    private var unassigned: [TodoItem] {
        uncompletedTodos.filter { eisStore.quadrant(of: $0.id) == nil }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.06, blue: 0.13),
                         Color(red: 0.1,  green: 0.06, blue: 0.18)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Header
                    headerSection
                        .padding(.top, 24)
                        .padding(.horizontal, 20)

                    // Matrix grid
                    VStack(spacing: 0) {
                        // Labels row
                        HStack {
                            Spacer()
                            label("⚡ Urgent")
                            Spacer()
                            label("🕐 Not urgent")
                            Spacer()
                        }
                        .padding(.bottom, 6)

                        HStack(alignment: .top, spacing: 8) {
                            // Important column label
                            VStack {
                                Spacer()
                                Text("Important")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.35))
                                    .rotationEffect(.degrees(-90))
                                    .fixedSize()
                                Spacer()
                                Text("Not important")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.35))
                                    .rotationEffect(.degrees(-90))
                                    .fixedSize()
                            }
                            .frame(width: 18)

                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    quadrantCell(.q1)
                                    quadrantCell(.q2)
                                }
                                HStack(spacing: 8) {
                                    quadrantCell(.q3)
                                    quadrantCell(.q4)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Unassigned tasks
                    if !unassigned.isEmpty {
                        unassignedSection
                            .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 32)
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .sheet(item: $assignSheet) { todo in
            QuadrantPickerSheet(todo: todo, accent: accent)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Eisenhower Matrix")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Prioritize by importance & urgency")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
            }

            // Summary chips
            HStack(spacing: 8) {
                ForEach(EisenhowerQuadrant.allCases) { q in
                    let count = todos(in: q).count
                    HStack(spacing: 4) {
                        Circle().fill(q.color).frame(width: 8, height: 8)
                        Text("\(count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(q.color.opacity(0.15), in: Capsule())
                }
                Spacer()
                if !unassigned.isEmpty {
                    Text("\(unassigned.count) unsorted")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    // MARK: - Quadrant Cell

    private func quadrantCell(_ q: EisenhowerQuadrant) -> some View {
        let items = todos(in: q)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: q.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(q.color)
                Text(q.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(q.color)
                Spacer()
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(q.color.opacity(0.8))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(q.color.opacity(0.15), in: Capsule())
                }
            }

            if items.isEmpty {
                Text("Assign task →")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.2))
                    .italic()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(items.prefix(4)) { todo in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(q.color.opacity(0.7))
                                .frame(width: 5, height: 5)
                            Text(todo.title)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(2)
                            Spacer()
                            Button {
                                eisStore.unassign(todo.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.25))
                            }
                        }
                    }
                    if items.count > 4 {
                        Text("+\(items.count - 4) more")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(q.color.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(q.color.opacity(items.isEmpty ? 0.15 : 0.35), lineWidth: 1)
                )
        )
    }

    // MARK: - Unassigned

    private var unassignedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Uncategorized (\(unassigned.count))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            ForEach(unassigned) { todo in
                Button { assignSheet = todo } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 13))
                            .foregroundStyle(accent)
                        Text(todo.title)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                        Spacer()
                        Text("Classify")
                            .font(.system(size: 11))
                            .foregroundStyle(accent.opacity(0.7))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.35))
    }
}

// MARK: - Quadrant Picker Sheet

struct QuadrantPickerSheet: View {
    let todo: TodoItem
    let accent: Color

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = EisenhowerStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.14).ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("\u{201E}\(todo.title)\u{201D}")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    Text("Which quadrant does this task belong to?")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.45))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(EisenhowerQuadrant.allCases) { q in
                            Button {
                                store.assign(todo.id, to: q)
                                dismiss()
                            } label: {
                                VStack(spacing: 10) {
                                    Image(systemName: q.icon)
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(q.color)
                                    Text(q.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text(q.label)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.45))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(q.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(q.color.opacity(0.35), lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationTitle("Classify Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

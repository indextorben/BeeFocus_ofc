import SwiftUI

struct HabitTrackerView: View {
    @ObservedObject private var store = HabitStore.shared
    @ObservedObject private var sub = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var showAddSheet = false
    @State private var editingHabit: Habit? = nil
    @State private var bouncedHabitID: UUID? = nil

    private var c1: Color { appThemaFarben(aktivesThema).0 }
    private var c2: Color { appThemaFarben(aktivesThema).1 }
    private var accent: Color { aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : c1 }

    var body: some View {
        ZStack {
            ThemeBackgroundView().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    headerProgress
                        .padding(.top, 24)
                        .padding(.horizontal, 20)

                    if store.habits.isEmpty {
                        emptyState
                            .padding(.top, 40)
                            .padding(.horizontal, 20)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(store.habits) { habit in
                                HabitCard(
                                    habit: habit,
                                    accent: accent,
                                    bounced: bouncedHabitID == habit.id
                                ) {
                                    store.toggle(habit)
                                    let gen = UIImpactFeedbackGenerator(style: .medium)
                                    gen.impactOccurred()
                                    bouncedHabitID = habit.id
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                        bouncedHabitID = nil
                                    }
                                } onEdit: {
                                    editingHabit = habit
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Pro gate: show add button always, but limit for free users
                    addButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
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
        .sheet(isPresented: $showAddSheet) {
            HabitAddSheet(existing: nil, accent: accent)
        }
        .sheet(item: $editingHabit) { habit in
            HabitAddSheet(existing: habit, accent: accent)
        }
    }

    // MARK: - Header Progress

    private var headerProgress: some View {
        let progress = store.todayProgress()
        let pct = progress.total > 0 ? Double(progress.done) / Double(progress.total) : 0

        return VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Habits")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Today, \(Date().formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.1), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: pct)
                        .stroke(
                            LinearGradient(colors: [accent, accent.opacity(0.5)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: pct)
                    VStack(spacing: 0) {
                        Text("\(progress.done)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        Text("/ \(progress.total)")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(width: 64, height: 64)
            }

            if progress.total > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.08))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [accent, accent.opacity(0.6)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * pct, height: 6)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: pct)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(18)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(accent.opacity(0.6))
            Text("No Habits")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("Add your first daily habit and watch it become a routine.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    // MARK: - Add Button

    private var addButton: some View {
        let freeLimit = 3
        let atLimit = !sub.isPro && store.habits.count >= freeLimit

        return Button {
            if atLimit {
                NotificationCenter.default.post(name: .showPaywall, object: nil)
                dismiss()
            } else {
                showAddSheet = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: atLimit ? "lock.fill" : "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(atLimit ? "Pro for more habits" : "Add habit")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                atLimit
                    ? AnyShapeStyle(Color.white.opacity(0.08))
                    : AnyShapeStyle(LinearGradient(colors: [accent, accent.opacity(0.6)],
                                                   startPoint: .leading, endPoint: .trailing))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(atLimit ? accent.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Habit Card

struct HabitCard: View {
    let habit: Habit
    let accent: Color
    let bounced: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void

    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var isDone: Bool { habit.isCompleted(on: today) }

    var body: some View {
        HStack(spacing: 14) {
            // Checkmark button
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(isDone ? habit.color.opacity(0.25) : Color.white.opacity(0.07))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(isDone ? habit.color : Color.white.opacity(0.2), lineWidth: 2)
                        )
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(habit.color)
                    } else {
                        Image(systemName: habit.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
                .scaleEffect(bounced ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: bounced)
            }
            .buttonStyle(.plain)

            // Info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: habit.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(habit.color)
                    Text(habit.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isDone ? .white.opacity(0.6) : .white)
                        .strikethrough(isDone, color: .white.opacity(0.4))
                }

                // Last 7 days dots
                HStack(spacing: 5) {
                    ForEach(habit.last7Days(), id: \.date) { day in
                        let isFuture = day.date > today
                        Circle()
                            .fill(day.done ? habit.color : Color.white.opacity(isFuture ? 0.05 : 0.12))
                            .frame(width: 8, height: 8)
                    }
                    Spacer()
                }
            }

            Spacer()

            // Streak
            VStack(spacing: 2) {
                let streak = habit.currentStreak
                if streak > 0 {
                    HStack(spacing: 3) {
                        Text("🔥")
                            .font(.system(size: 14))
                        Text("\(streak)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("Streak")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    Text("\(habit.totalCompletions)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("Total")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .onTapGesture { onEdit() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDone ? habit.color.opacity(0.08) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isDone ? habit.color.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isDone)
    }
}

// MARK: - Add/Edit Sheet

struct HabitAddSheet: View {
    let existing: Habit?
    let accent: Color

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = HabitStore.shared

    @State private var name: String = ""
    @State private var selectedIcon: String = "star.fill"
    @State private var selectedColor: String = "purple"

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.14).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Preview
                        ZStack {
                            Circle()
                                .fill(habitColor.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay(Circle().stroke(habitColor.opacity(0.5), lineWidth: 2))
                            Image(systemName: selectedIcon)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(habitColor)
                        }
                        .padding(.top, 8)

                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            label("Name")
                            TextField("e.g. Read every day", text: $name)
                                .font(.system(size: 16))
                                .padding(14)
                                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                        }

                        // Icon Picker
                        VStack(alignment: .leading, spacing: 10) {
                            label("Icon")
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                                ForEach(Habit.availableIcons.filter { !$0.contains("🧘") }, id: \.self) { icon in
                                    Button {
                                        selectedIcon = icon
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedIcon == icon ? habitColor.opacity(0.25) : Color.white.opacity(0.07))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(selectedIcon == icon ? habitColor : Color.clear, lineWidth: 1.5)
                                                )
                                            Image(systemName: icon)
                                                .font(.system(size: 18))
                                                .foregroundStyle(selectedIcon == icon ? habitColor : .white.opacity(0.6))
                                        }
                                        .frame(height: 44)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Color Picker
                        VStack(alignment: .leading, spacing: 10) {
                            label("Color")
                            HStack(spacing: 12) {
                                ForEach(Habit.availableColors, id: \.name) { c in
                                    let col = colorFor(c.name)
                                    Button { selectedColor = c.name } label: {
                                        Circle()
                                            .fill(col)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle()
                                                    .stroke(.white, lineWidth: selectedColor == c.name ? 2.5 : 0)
                                            )
                                            .shadow(color: col.opacity(0.5), radius: selectedColor == c.name ? 6 : 0)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(existing == nil ? "Add Habit" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(name.isEmpty ? .gray : habitColor)
                        .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let h = existing {
                    name          = h.name
                    selectedIcon  = h.icon
                    selectedColor = h.colorName
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var habitColor: Color { colorFor(selectedColor) }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.5))
            .padding(.leading, 4)
    }

    private func colorFor(_ name: String) -> Color {
        var dummy = Habit(name: ""); dummy.colorName = name; return dummy.color
    }

    private func save() {
        var h = existing ?? Habit(name: "")
        h.name       = name.trimmingCharacters(in: .whitespaces)
        h.icon       = selectedIcon
        h.colorName  = selectedColor
        if existing != nil { store.update(h) } else { store.add(h) }
        dismiss()
    }
}

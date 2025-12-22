import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject private var localizer = LocalizationManager.shared

    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()

    private let calendar = Calendar.current
    private let daysOfWeekKeys = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"] // Übersetzbar

    // MARK: - Colors
    private var accentBlue: Color { .blue }
    private var background: Color {
        colorScheme == .dark
        ? Color(red: 0.08, green: 0.1, blue: 0.18)
        : Color(red: 0.94, green: 0.97, blue: 1.0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()

                VStack(spacing: 16) {
                    headerCard
                    calendarCard
                    todoCard
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(localizer.localizedString(forKey: "Kalender"))
        }
    }

    // MARK: - Header
    private var headerCard: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text(localizer.localizedString(forKey: "-"))
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Spacer()

            Text(monthYearString(from: currentMonth))
                .font(.title2.bold())

            Spacer()

            Button(action: { changeMonth(by: 1) }) {
                HStack(spacing: 4) {
                    Text(localizer.localizedString(forKey: "+"))
                        .font(.subheadline.bold())
                    Image(systemName: "chevron.right")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(BlurView(style: .systemUltraThinMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Calendar Card
    private var calendarCard: some View {
        VStack(spacing: 12) {

            // Weekdays
            HStack {
                ForEach(daysOfWeekKeys, id: \.self) { key in
                    Text(localizer.localizedString(forKey: key))
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }

            // Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                ForEach(generateDaysInMonth(for: currentMonth), id: \.self) { date in
                    dayCell(for: date)
                }
            }
        }
        .padding()
        .background(BlurView(style: .systemUltraThinMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
    }

    // MARK: - Day Cell
    private func dayCell(for date: Date?) -> some View {
        Group {
            if let date {
                let isSelected = isSameDay(date, selectedDate)
                let isToday = calendar.isDateInToday(date)

                VStack(spacing: 6) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(
                                    isSelected
                                    ? accentBlue
                                    : isToday
                                        ? accentBlue.opacity(0.2)
                                        : Color.clear
                                )
                        )

                    if hasTodos(on: date) {
                        Circle()
                            .fill(accentBlue)
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedDate = date
                    }
                }

            } else {
                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Todo Card
    private var todoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(localizer.localizedString(forKey: "Aufgaben am")) \(formattedDate(selectedDate))")
                .font(.headline)

            let todos = todosForDay(selectedDate)

            if todos.isEmpty {
                Text(localizer.localizedString(forKey: "Keine Aufgaben. Chill mal 😴"))
                    .foregroundColor(.secondary)
            } else {
                ForEach(todos) { todo in
                    NavigationLink(destination: TodoDetailView(todo: todo)) {
                        HStack {
                            Circle()
                                .fill(accentBlue)
                                .frame(width: 8, height: 8)

                            Text(todo.title)
                                .font(.subheadline)

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(BlurView(style: .systemUltraThinMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Helpers
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func generateDaysInMonth(for date: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }

        let firstOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let offset = (firstWeekday + 5) % 7

        let range = calendar.range(of: .day, in: .month, for: date) ?? 1..<1
        var days: [Date?] = Array(repeating: nil, count: offset)
        
        for day in range {
            if let dayDate = calendar.date(bySetting: .day, value: day, of: firstOfMonth) {
                days.append(dayDate)
            }
        }
        
        return days
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localizer.selectedLanguage == "Englisch" ? "en_US" : "de_DE")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func isSameDay(_ d1: Date, _ d2: Date) -> Bool {
        calendar.isDate(d1, inSameDayAs: d2)
    }

    private func hasTodos(on date: Date) -> Bool {
        todosForDay(date).isEmpty == false
    }

    private func todosForDay(_ date: Date) -> [TodoItem] {
        todoStore.todos.filter {
            guard let dueDate = $0.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
            && !$0.isCompleted
        }
    }
}

// MARK: - Todo Detail View
struct TodoDetailView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.colorScheme) var colorScheme
    @State private var isCompleted: Bool
    let todo: TodoItem
    
    init(todo: TodoItem) {
        self.todo = todo
        _isCompleted = State(initialValue: todo.isCompleted)
    }

    // Farben und Status-Helper
    private var accentBlue: Color { .blue }
    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0.14, green: 0.16, blue: 0.26) : Color(red: 0.97, green: 0.99, blue: 1.0)
    }
    private var overdueColor: Color { .red }
    private var dueSoonColor: Color { .orange }
    private var completedColor: Color { .green }
    
    private var dueStatus: (icon: String, text: String, color: Color)? {
        guard !isCompleted, let dueDate = todo.dueDate else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let due = Calendar.current.startOfDay(for: dueDate)
        if due < today {
            return ("exclamationmark.triangle.fill", "Überfällig", overdueColor)
        } else if due == today {
            return ("clock.badge.exclamationmark", "Fällig heute", dueSoonColor)
        } else if due <= Calendar.current.date(byAdding: .day, value: 2, to: today) ?? today {
            return ("hourglass", "Bald fällig", dueSoonColor)
        }
        return nil
    }

    var body: some View {
        ZStack {
            // Weiches Hintergrund-Gradient/Glas
            LinearGradient(gradient: Gradient(colors: [accentBlue.opacity(0.10), cardBackground]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {

                    // Header: Titel, Status, Fälligkeitsanzeige
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(todo.title)
                                .font(.title.bold())
                                .foregroundColor(.primary)
                                .lineLimit(3)
                            Spacer()
                            Button(action: toggleCompletion) {
                                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                    .resizable()
                                    .frame(width: 38, height: 38)
                                    .foregroundColor(isCompleted ? completedColor : Color.gray.opacity(0.55))
                                    .shadow(color: isCompleted ? completedColor.opacity(0.18) : .clear, radius: 6)
                            }
                        }
                        
                        if let dueDate = todo.dueDate {
                            HStack(spacing: 8) {
                                let status = dueStatus
                                if let status {
                                    Image(systemName: status.icon)
                                        .foregroundColor(status.color)
                                    Text(status.text)
                                        .foregroundColor(status.color)
                                        .font(.subheadline.bold())
                                }
                                Text("Fällig am: ")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                Text(dueDate.formatted(.dateTime.day().month().year()))
                                    .foregroundColor(.primary)
                                    .font(.subheadline)
                            }
                        } else if isCompleted {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal")
                                    .foregroundColor(completedColor)
                                Text("Erledigt!")
                                    .font(.subheadline.bold())
                                    .foregroundColor(completedColor)
                            }
                        }
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 7)

                    // Details Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Details")
                            .font(.headline)
                            .padding(.bottom, 2)
                        Text(todo.description.isEmpty ? "Keine weiteren Details." : todo.description)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 4)

                    // Subtasks Card
                    if !todo.subTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Unteraufgaben")
                                .font(.headline)
                            ForEach(todo.subTasks) { sub in
                                HStack {
                                    Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(sub.isCompleted ? completedColor : .gray)
                                    Text(sub.title)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                        .shadow(color: .black.opacity(0.06), radius: 7, x: 0, y: 3)
                    }

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 44)
            }
        }
        .navigationTitle("Aufgabe")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleCompletion() {
        isCompleted.toggle()
        if let index = todoStore.todos.firstIndex(of: todo) {
            todoStore.todos[index].isCompleted = isCompleted
        }
    }
}

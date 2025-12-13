import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()

    private let calendar = Calendar.current
    private let daysOfWeek = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    // MARK: - Colors
    private var accentBlue: Color { .blue }
    private var background: Color {
        colorScheme == .dark
        ? Color(red: 0.08, green: 0.1, blue: 0.18)
        : Color(red: 0.94, green: 0.97, blue: 1.0)
    }

    var body: some View {
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
        .navigationTitle("Kalender")
    }

    // MARK: - Header
    private var headerCard: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(monthYearString(from: currentMonth))
                .font(.title2.bold())

            Spacer()

            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
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
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
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
            Text("Aufgaben am \(formattedDate(selectedDate))")
                .font(.headline)

            let todos = todosForDay(selectedDate)

            if todos.isEmpty {
                Text("Keine Aufgaben. Chill mal 😴")
                    .foregroundColor(.secondary)
            } else {
                ForEach(todos) { todo in
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
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: date),
            let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday
        else { return [] }

        let offset = (firstWeekday + 5) % 7
        let days = calendar.range(of: .day, in: .month, for: date) ?? 1..<1

        var result: [Date?] = Array(repeating: nil, count: offset)

        for day in days {
            if let date = calendar.date(bySetting: .day, value: day, of: date) {
                result.append(date)
            }
        }
        return result
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
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

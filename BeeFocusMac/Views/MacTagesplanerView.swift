import SwiftUI

struct MacTagesplanerView: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showAddSheet = false
    @State private var newTitle = ""
    @State private var newTime  = Date()

    private let cal = Calendar.current
    private let hourHeight: CGFloat = 56

    var body: some View {
        HStack(spacing: 0) {
            // Left: date strip
            dateSidebar
            Divider()
            // Right: timeline
            VStack(spacing: 0) {
                dayHeader
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        timelineContent
                            .padding(.bottom, 20)
                    }
                    .onAppear {
                        proxy.scrollTo("hour-\(cal.component(.hour, from: Date()))", anchor: .top)
                    }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showAddSheet) { addSheet }
    }

    // MARK: - Date Sidebar

    private var dateSidebar: some View {
        VStack(spacing: 0) {
            Text(monthYear)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ForEach(daysInWeek, id: \.self) { day in
                let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
                let isToday    = cal.isDateInToday(day)
                Button { selectedDate = cal.startOfDay(for: day) } label: {
                    VStack(spacing: 2) {
                        Text(weekdayShort(day))
                            .font(.system(size: 10))
                            .foregroundStyle(isToday ? .orange : .secondary)
                        Text("\(cal.component(.day, from: day))")
                            .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                            .foregroundStyle(isSelected ? .white : (isToday ? .orange : .primary))
                            .frame(width: 34, height: 34)
                            .background(isSelected ? Color.orange : Color.clear, in: Circle())
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)

                // Dot if tasks exist
                let taskCount = todos(for: day).count
                Circle()
                    .fill(taskCount > 0 ? Color.orange.opacity(0.7) : Color.clear)
                    .frame(width: 4, height: 4)
                    .padding(.bottom, 4)
            }

            Spacer()

            Button {
                selectedDate = cal.startOfDay(for: Date())
            } label: {
                Text("Heute")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        }
        .frame(width: 60)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Day Header

    private var dayHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(fullDateLabel)
                    .font(.system(size: 16, weight: .bold))
                let count = timedTodos.count + untimedTodos.count
                Text("\(count) Aufgabe\(count == 1 ? "" : "n")")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                newTime = cal.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                showAddSheet = true
            } label: {
                Label("Aufgabe hinzufügen", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Timeline

    private var timelineContent: some View {
        VStack(spacing: 0) {
            // Untimed tasks
            if !untimedTodos.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("OHNE UHRZEIT")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 60)
                        .padding(.vertical, 6)
                    ForEach(untimedTodos) { todo in
                        todoRow(todo, time: nil)
                    }
                }
                Divider().padding(.leading, 60)
            }

            // Hourly timeline
            ForEach(6..<23, id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    // Hour label
                    Text(String(format: "%02d:00", hour))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                        .padding(.top, 2)
                        .padding(.trailing, 8)

                    // Divider line
                    VStack(spacing: 0) {
                        Divider()
                        Spacer()
                    }
                    .frame(width: 1, height: hourHeight)

                    // Tasks at this hour
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(todos(atHour: hour)) { todo in
                            todoRow(todo, time: todo.dueDate)
                        }
                    }
                    .padding(.leading, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: hourHeight)
                .id("hour-\(hour)")
                .background(cal.component(.hour, from: Date()) == hour && cal.isDateInToday(selectedDate)
                    ? Color.orange.opacity(0.04) : Color.clear)
            }
        }
        .padding(.top, 8)
    }

    private func todoRow(_ todo: MacTodoItem, time: Date?) -> some View {
        HStack(spacing: 8) {
            // Priority stripe
            RoundedRectangle(cornerRadius: 2)
                .fill(priorityColor(todo.priority))
                .frame(width: 3, height: 28)

            Button { todoStore.toggle(todo) } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? Color.green : Color.secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(todo.title)
                    .font(.system(size: 13))
                    .strikethrough(todo.isCompleted, color: .secondary)
                    .foregroundStyle(todo.isCompleted ? Color.secondary : Color.primary)
                    .lineLimit(1)
                if let t = time {
                    Text(shortTime(t))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    // MARK: - Add Sheet

    private var addSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Aufgabe hinzufügen")
                .font(.headline)
            TextField("Aufgabenname", text: $newTitle)
                .textFieldStyle(.roundedBorder)
            DatePicker("Uhrzeit", selection: $newTime, displayedComponents: [.hourAndMinute])
            HStack {
                Spacer()
                Button("Abbrechen") { showAddSheet = false }
                    .keyboardShortcut(.cancelAction)
                Button("Hinzufügen") {
                    guard !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let item = MacTodoItem(title: newTitle, dueDate: newTime)
                    todoStore.addTodo(item)
                    newTitle = ""
                    showAddSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    // MARK: - Computed

    private var timedTodos: [MacTodoItem]   { todos(for: selectedDate).filter { $0.dueDate != nil } }
    private var untimedTodos: [MacTodoItem] { todos(for: selectedDate).filter { $0.dueDate == nil } }

    private func todos(for day: Date) -> [MacTodoItem] {
        todoStore.todos.filter {
            guard let due = $0.dueDate else { return cal.isDate($0.createdAt, inSameDayAs: day) }
            return cal.isDate(due, inSameDayAs: day)
        }
    }

    private func todos(atHour hour: Int) -> [MacTodoItem] {
        timedTodos.filter {
            guard let due = $0.dueDate else { return false }
            return cal.component(.hour, from: due) == hour
        }
        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private var daysInWeek: [Date] {
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let monday  = cal.date(byAdding: .day, value: 2 - weekday, to: today) ?? today
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    private var monthYear: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.locale = Locale(identifier: "de_DE")
        return f.string(from: selectedDate)
    }

    private var fullDateLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, d. MMMM"; f.locale = Locale(identifier: "de_DE")
        return f.string(from: selectedDate)
    }

    private func weekdayShort(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EE"; f.locale = Locale(identifier: "de_DE")
        return f.string(from: date)
    }

    private func shortTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func priorityColor(_ p: MacTodoPriority) -> Color {
        let (r, g, b) = p.color
        return Color(red: r, green: g, blue: b)
    }
}

import SwiftUI
import Combine

struct MacTagesplanerView: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showQuickAdd = false
    @State private var editingTodo: MacTodoItem? = nil
    @State private var now: Date = Date()

    private var cal: Calendar { Calendar.current }
    private var isDark: Bool { colorScheme == .dark }
    private var isToday: Bool { cal.isDateInToday(selectedDate) }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    var body: some View {
        ZStack {
            ThemeBackgroundView()

            VStack(spacing: 0) {
                viewHeader

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            weekStrip
                            progressCard
                            treeTimeline
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                    .onAppear {
                        now = Date()
                        if isToday {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    proxy.scrollTo("nowIndicator", anchor: .center)
                                }
                            }
                        }
                    }
                    .onChange(of: selectedDate) { _ in
                        if isToday {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    proxy.scrollTo("nowIndicator", anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            now = Date()
        }
        .sheet(isPresented: $showQuickAdd) {
            MacTagesplanQuickAddSheet(selectedDate: selectedDate, themeC1: themeC1, themeC2: themeC2) { title, time, end in
                let item = MacTodoItem(title: title, dueDate: time, endTime: end)
                todoStore.addTodo(item)
            }
        }
        .sheet(item: $editingTodo) { todo in
            MacEditTodoSheet(todo: todo).environmentObject(todoStore)
        }
    }

    // MARK: - View Header

    private var viewHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedDateTitle)
                    .font(.system(size: 28, weight: .bold))
                let count = dayTodos(for: selectedDate).count
                Text("\(count) Aufgabe\(count == 1 ? "" : "n")")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showQuickAdd = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(themeC1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDate = cal.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeC1)
                    .frame(width: 28, height: 44)
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                ForEach(currentWeekDays(), id: \.self) { day in
                    let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
                    let isTodayDay = cal.isDateInToday(day)
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedDate = day
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text(shortWeekday(day))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : (isDark ? .white.opacity(0.5) : .secondary))
                            ZStack {
                                Circle()
                                    .fill(isSelected
                                          ? AnyShapeStyle(LinearGradient(colors: [themeC1, themeC2],
                                                                          startPoint: .top, endPoint: .bottom))
                                          : (isTodayDay
                                             ? AnyShapeStyle(themeC1.opacity(0.15))
                                             : AnyShapeStyle(Color.clear)))
                                    .frame(width: 30, height: 30)
                                Text("\(cal.component(.day, from: day))")
                                    .font(.system(size: 13, weight: isSelected || isTodayDay ? .bold : .regular))
                                    .foregroundStyle(isSelected ? .white : (isDark ? .white.opacity(0.85) : .primary))
                            }
                            let hasTasks = todoStore.todos.contains {
                                guard let due = $0.dueDate else { return false }
                                return cal.isDate(due, inSameDayAs: day) && !$0.isCompleted
                            }
                            Circle()
                                .fill(hasTasks ? themeC1 : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDate = cal.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeC1)
                    .frame(width: 28, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .themeGlass(cornerRadius: 14)
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        let todos  = dayTodos(for: selectedDate)
        let done   = todos.filter { $0.isCompleted }.count
        let total  = todos.count
        let prog   = total > 0 ? Double(done) / Double(total) : 0.0

        return HStack(spacing: 14) {
            ZStack {
                Circle().stroke(themeC1.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: prog)
                    .stroke(LinearGradient(colors: [themeC1, themeC2],
                                          startPoint: .leading, endPoint: .trailing),
                           style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: prog)
                Text("\(Int(prog * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isDark ? .white : .primary)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(greetingOrDateLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                Text(total == 0 ? "Keine Aufgaben eingeplant"
                                : "\(done) von \(total) erledigt")
                    .font(.caption)
                    .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
            }

            Spacer()

            if !isToday {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDate = cal.startOfDay(for: Date())
                    }
                } label: {
                    Text("Heute")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(themeC1)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(themeC1.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .themeGlass(cornerRadius: 16)
    }

    // MARK: - Tree Timeline

    private var treeTimeline: some View {
        VStack(spacing: 0) {
            untimedSection
            treeSectionView(label: "Morgen", icon: "sun.and.horizon.fill", color: .orange,  hours: 6..<12)
            treeSectionView(label: "Mittag",  icon: "sun.max.fill",         color: themeC1,  hours: 12..<18)
            treeSectionView(label: "Abend",   icon: "moon.stars.fill",      color: .indigo,  hours: 18..<24)
        }
        .padding(.horizontal, 4)
    }

    // Aufgaben ohne Uhrzeit
    @ViewBuilder
    private var untimedSection: some View {
        let items = dayTodos(for: selectedDate).filter { $0.dueDate == nil }
        if !items.isEmpty {
            VStack(spacing: 0) {
                sectionHeader(label: "Ohne Uhrzeit", icon: "tray.fill", color: .secondary)
                ForEach(items) { todo in
                    taskRow(todo: todo, showTime: false)
                }
            }
        }
    }

    @ViewBuilder
    private func treeSectionView(label: String, icon: String, color: Color, hours: Range<Int>) -> some View {
        let tasks = tasksForHours(hours)
        let sectionStart = cal.date(bySettingHour: hours.lowerBound, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let sectionEnd: Date = {
            if hours.upperBound == 24 {
                return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: selectedDate)) ?? selectedDate
            }
            return cal.date(bySettingHour: hours.upperBound, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        }()
        let nowInSection = isToday && now >= sectionStart && now < sectionEnd

        VStack(spacing: 0) {
            sectionHeader(label: label, icon: icon, color: color)

            if tasks.isEmpty {
                if nowInSection { nowIndicatorRow }
                freeTimeRow(
                    minutes: CGFloat(max(sectionEnd.timeIntervalSince(sectionStart) / 60, 0)),
                    color: color,
                    showHint: true
                )
            } else {
                // Gap before first task
                if let firstDue = tasks.first?.dueDate {
                    let preGap = CGFloat(max(firstDue.timeIntervalSince(sectionStart) / 60, 0))
                    if preGap > 5 { freeTimeRow(minutes: preGap, color: color, showHint: false) }
                }

                // Now indicator position
                let nowBeforeFirst = nowInSection && tasks.first.map { now < ($0.dueDate ?? .distantFuture) } ?? false
                if nowBeforeFirst { nowIndicatorRow }

                ForEach(Array(tasks.enumerated()), id: \.element.id) { idx, task in
                    taskRow(todo: task, showTime: true)

                    let nextStart = idx + 1 < tasks.count ? (tasks[idx + 1].dueDate ?? sectionEnd) : sectionEnd
                    let gapMins = CGFloat(max(nextStart.timeIntervalSince(task.dueDate ?? sectionEnd) / 60, 0))

                    let nowAfterThis = nowInSection
                        && now >= (task.dueDate ?? sectionStart)
                        && (idx + 1 >= tasks.count || now < (tasks[idx + 1].dueDate ?? sectionEnd))
                    if nowAfterThis { nowIndicatorRow }

                    if gapMins > 5 { freeTimeRow(minutes: gapMins, color: color, showHint: false) }
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(label: String, icon: String, color: Color) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Spacer().frame(width: 52)
            ZStack {
                Circle().fill(color.opacity(0.18)).frame(width: 22, height: 22)
                Circle().fill(color).frame(width: 11, height: 11)
            }
            .frame(width: 20)
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(color)
            .padding(.leading, 10)
            Rectangle()
                .fill(color.opacity(0.18))
                .frame(height: 1)
                .padding(.leading, 8)
        }
        .padding(.top, 22)
        .padding(.bottom, 4)
        .padding(.trailing, 4)
    }

    // MARK: - Task Row

    private func taskRow(todo: MacTodoItem, showTime: Bool) -> some View {
        let lineColor = isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
        let endDate   = todo.endTime ?? (todo.dueDate?.addingTimeInterval(3600))
        let isActive  = isToday && !todo.isCompleted
            && todo.dueDate.map { start in now >= start && now < (endDate ?? .distantFuture) } ?? false
        let borderColor: Color = todo.isCompleted ? .green.opacity(0.35)
                               : isActive         ? themeC1.opacity(0.6)
                               :                    themeC1.opacity(0.28)
        let bgColor: Color = todo.isCompleted ? .green.opacity(isDark ? 0.08 : 0.05)
                           : isActive         ? themeC1.opacity(isDark ? 0.18 : 0.10)
                           :                   themeC1.opacity(isDark ? 0.12 : 0.07)

        return HStack(alignment: .top, spacing: 0) {
            // Zeit-Spalte (nur Startzeit)
            Group {
                if showTime, let due = todo.dueDate {
                    Text(shortTime(due))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(todo.isCompleted ? .secondary : themeC1)
                } else {
                    Color.clear
                }
            }
            .frame(width: 44, alignment: .trailing)
            .padding(.trailing, 8)
            .padding(.top, 10)

            // Spine: Punkt + Linie
            VStack(spacing: 0) {
                ZStack {
                    if todo.isCompleted {
                        Circle().fill(Color.green.opacity(0.25)).frame(width: 14, height: 14)
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Color.green)
                    } else if isActive {
                        Circle().fill(themeC1.opacity(0.2)).frame(width: 16, height: 16)
                        Circle().fill(themeC1).frame(width: 8, height: 8)
                    } else {
                        Circle().fill(themeC1.opacity(0.6)).frame(width: 9, height: 9)
                    }
                }
                .padding(.top, 8)
                Rectangle()
                    .fill(lineColor)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)

            // Karte
            HStack(alignment: .top, spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        todoStore.toggle(todo)
                    }
                } label: {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17))
                        .foregroundStyle(todo.isCompleted ? Color.green : themeC1.opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(todo.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isDark ? .white.opacity(0.95) : Color.primary)
                        .strikethrough(todo.isCompleted, color: .secondary)
                        .lineLimit(2)

                    // Zeitspanne (Startzeit – Endzeit)
                    if showTime, let due = todo.dueDate, !todo.isCompleted {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            if let end = todo.endTime {
                                Text("\(shortTime(due)) – \(shortTime(end))")
                            } else {
                                Text("ab \(shortTime(due))")
                            }
                        }
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    }

                    if !todo.description.isEmpty {
                        Text(todo.description)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    // Timer-Badge
                    if isToday, !todo.isCompleted, let due = todo.dueDate {
                        timerBadge(due: due, endDate: endDate, isActive: isActive)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    if todo.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                    }
                    Button { editingTodo = todo } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(themeC1.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 10).fill(bgColor)
                if !aktivesThema.isEmpty {
                    TaskCardThemeDecoration(theme: aktivesThema, isDark: isDark, isActive: isActive)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .allowsHitTesting(false)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderColor, lineWidth: isActive ? 1.5 : 1))
            .padding(.leading, 10)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity)
        }
        .opacity(todo.isCompleted ? 0.55 : 1.0)
        .onTapGesture { editingTodo = todo }
    }

    @ViewBuilder
    private func timerBadge(due: Date, endDate: Date?, isActive: Bool) -> some View {
        if now < due {
            // Noch nicht gestartet
            let diff = due.timeIntervalSince(now)
            HStack(spacing: 3) {
                Image(systemName: "hourglass")
                    .font(.system(size: 8, weight: .semibold))
                Text("in \(formatInterval(diff))")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(.orange.opacity(isDark ? 0.18 : 0.12), in: Capsule())
        } else if isActive, let end = endDate {
            // Läuft gerade – Restzeit
            let diff = end.timeIntervalSince(now)
            HStack(spacing: 3) {
                Circle().fill(themeC1).frame(width: 5, height: 5)
                Text("noch \(formatInterval(diff))")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(themeC1)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(themeC1.opacity(isDark ? 0.18 : 0.12), in: Capsule())
        } else if isActive {
            // Läuft gerade, keine Endzeit
            HStack(spacing: 3) {
                Circle().fill(themeC1).frame(width: 5, height: 5)
                Text("läuft gerade")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(themeC1)
        } else if let end = endDate, now >= end {
            // Überfällig (Endzeit überschritten)
            let diff = now.timeIntervalSince(end)
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 9))
                Text("\(formatInterval(diff)) überfällig")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(.red)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(.red.opacity(isDark ? 0.18 : 0.10), in: Capsule())
        }
    }

    private func formatInterval(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return m > 0 ? "\(h)h \(m)min" : "\(h)h" }
        return "\(max(m, 1))min"
    }

    // MARK: - Now Indicator

    private var nowIndicatorRow: some View {
        let fmt: DateFormatter = {
            let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
        }()
        return HStack(spacing: 0) {
            Text(fmt.string(from: now))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(themeC1)
                .frame(width: 44, alignment: .trailing)
                .padding(.trailing, 8)
            ZStack {
                Circle().fill(themeC1.opacity(0.2)).frame(width: 18, height: 18)
                Circle().fill(themeC1).frame(width: 9, height: 9)
            }
            .frame(width: 20)
            Rectangle()
                .fill(LinearGradient(colors: [themeC1, themeC1.opacity(0)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1.5)
                .padding(.leading, 10)
                .padding(.trailing, 4)
        }
        .padding(.vertical, 4)
        .id("nowIndicator")
    }

    // MARK: - Free Time Row

    @ViewBuilder
    private func freeTimeRow(minutes: CGFloat, color: Color, showHint: Bool) -> some View {
        let lineColor = isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
        let height = max(min(minutes * 1.0, 90), 20)
        HStack(alignment: .center, spacing: 0) {
            Spacer().frame(width: 52)
            Rectangle().fill(lineColor).frame(width: 2, height: height)
                .frame(width: 20)
            if showHint {
                Button { showQuickAdd = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 9, weight: .bold))
                        Text(minutes >= 60
                             ? "\(Int(minutes/60))h\(Int(minutes)%60 > 0 ? " \(Int(minutes)%60)min" : "") frei"
                             : "\(Int(minutes))min frei")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(isDark ? .white.opacity(0.22) : Color.secondary.opacity(0.5))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(color.opacity(0.25)))
                }
                .buttonStyle(.plain)
                .padding(.leading, 10)
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private func dayTodos(for day: Date) -> [MacTodoItem] {
        todoStore.todos.filter {
            if let due = $0.dueDate { return cal.isDate(due, inSameDayAs: day) }
            return cal.isDate($0.createdAt, inSameDayAs: day)
        }
    }

    private func tasksForHours(_ hours: Range<Int>) -> [MacTodoItem] {
        todoStore.todos.filter { todo in
            guard let due = todo.dueDate else { return false }
            guard cal.isDate(due, inSameDayAs: selectedDate) else { return false }
            return hours.contains(cal.component(.hour, from: due))
        }
        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private func currentWeekDays() -> [Date] {
        var cal2 = Calendar(identifier: .gregorian)
        cal2.firstWeekday = 2
        let weekStart = cal2.date(from: cal2.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
        return (0..<7).compactMap { cal2.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func shortWeekday(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "EEE"
        return String(f.string(from: date).prefix(2))
    }

    private func shortTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private var selectedDateTitle: String {
        if isToday { return "Heute" }
        let f = DateFormatter(); f.dateFormat = "EEEE, d. MMM"; f.locale = Locale(identifier: "de_DE")
        return f.string(from: selectedDate)
    }

    private var greetingOrDateLabel: String {
        if isToday {
            let h = cal.component(.hour, from: Date())
            if h < 12 { return "Guten Morgen" }
            if h < 18 { return "Guten Mittag" }
            return "Guten Abend"
        }
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "EEEE"
        return f.string(from: selectedDate)
    }
}

// MARK: - Quick Add Sheet

struct MacTagesplanQuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selectedDate: Date
    let themeC1: Color
    let themeC2: Color
    let onAdd: (String, Date?, Date?) -> Void

    @State private var title = ""
    @State private var hasTime = false
    @State private var hasEndTime = false
    @State private var time: Date
    @State private var endTime: Date

    init(selectedDate: Date, themeC1: Color, themeC2: Color, onAdd: @escaping (String, Date?, Date?) -> Void) {
        self.selectedDate = selectedDate
        self.themeC1 = themeC1
        self.themeC2 = themeC2
        self.onAdd = onAdd
        let cal = Calendar.current
        let start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        _time    = State(initialValue: start)
        _endTime = State(initialValue: cal.date(byAdding: .hour, value: 1, to: start) ?? start)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Aufgabe") {
                    TextField("Titel", text: $title)
                }
                Section {
                    Toggle("Uhrzeit festlegen", isOn: $hasTime.animation())
                    if hasTime {
                        DatePicker("Beginn", selection: $time, displayedComponents: [.hourAndMinute])
                        Toggle("Endzeit festlegen", isOn: $hasEndTime.animation())
                        if hasEndTime {
                            DatePicker("Ende", selection: $endTime, displayedComponents: [.hourAndMinute])
                        }
                    }
                }
            }
            .navigationTitle("Aufgabe einplanen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let finalTime: Date? = hasTime ? time : nil
                        let finalEnd: Date? = (hasTime && hasEndTime) ? endTime : nil
                        onAdd(title, finalTime, finalEnd)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(width: 360, height: 320)
    }
}

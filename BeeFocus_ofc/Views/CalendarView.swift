import SwiftUI
import EventKit

struct CalendarView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.colorScheme) var colorScheme

    @ObservedObject private var localizer = LocalizationManager.shared

    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = {
        let today = Date()
        return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: today)) ?? today
    }()
    @State private var showingCalendarImport = false
    @State private var showingAddTodo = false
    @GestureState private var dragOffset: CGFloat = 0

    private let cal = Calendar.current
    private let weekdayKeys = ["weekday_mon", "weekday_tue", "weekday_wed", "weekday_thu", "weekday_fri", "weekday_sat", "weekday_sun"]

    private var background: Color {
        colorScheme == .dark
            ? Color(red: 0.07, green: 0.09, blue: 0.16)
            : Color(red: 0.93, green: 0.96, blue: 1.0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        monthHeader
                        weekdayRow
                        dayGrid
                        selectedDaySection
                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(localizer.localizedString(forKey: "calendar_title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        let today = Date()
                        currentMonth = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
                        selectedDate = today
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.blue)
                    }

                    Button {
                        showingCalendarImport = true
                    } label: {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.blue)
                    }
                }
            }
            .sheet(isPresented: $showingCalendarImport) {
                CalendarImportView()
                    .environmentObject(todoStore)
            }
            .sheet(isPresented: $showingAddTodo) {
                AddTodoView(prefilledDate: selectedDate)
                    .environmentObject(todoStore)
            }
        }
    }

    // MARK: - Month Header
    private var monthHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.18), Color.purple.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: Color.blue.opacity(0.12), radius: 16, x: 0, y: 6)

            HStack(spacing: 0) {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(Color.blue)
                        .background(Color.blue.opacity(0.10), in: Circle())
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(monthName(from: currentMonth))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(yearString(from: currentMonth))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(Color.blue)
                        .background(Color.blue.opacity(0.10), in: Circle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width < -40 { changeMonth(by: 1) }
                    else if value.translation.width > 40 { changeMonth(by: -1) }
                }
        )
    }

    // MARK: - Weekday Row
    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdayKeys, id: \.self) { key in
                Text(localizer.localizedString(forKey: key))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Day Grid
    private var dayGrid: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 5)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
                    dayCellView(for: date)
                }
            }
            .padding(10)
        }
    }

    @ViewBuilder
    private func dayCellView(for date: Date?) -> some View {
        if let date {
            let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
            let isToday = cal.isDateInToday(date)
            let isWeekend = {
                let wd = cal.component(.weekday, from: date)
                return wd == 1 || wd == 7
            }()
            let todos = todosForDay(date)
            let hasTodos = !todos.isEmpty
            let hasOverdue = todos.contains { $0.isOverdue }

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    selectedDate = date
                }
            }) {
                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .fill(
                                isSelected
                                    ? Color.blue
                                    : isToday
                                        ? Color.blue.opacity(0.18)
                                        : Color.clear
                            )
                            .frame(width: 36, height: 36)

                        Text("\(cal.component(.day, from: date))")
                            .font(.system(size: 14, weight: isSelected || isToday ? .bold : .regular))
                            .foregroundStyle(
                                isSelected
                                    ? Color.white
                                    : isWeekend
                                        ? Color.blue.opacity(0.8)
                                        : Color.primary
                            )
                    }

                    if hasTodos {
                        HStack(spacing: 3) {
                            ForEach(0..<min(todos.count, 3), id: \.self) { i in
                                Circle()
                                    .fill(dotColor(for: todos[i], overdue: hasOverdue))
                                    .frame(width: 5, height: 5)
                            }
                        }
                    } else {
                        Color.clear.frame(height: 5)
                    }
                }
                .frame(height: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 52)
        }
    }

    private func dotColor(for todo: TodoItem, overdue: Bool) -> Color {
        if todo.isOverdue { return .red }
        switch todo.priority {
        case .high: return .orange
        case .medium: return .blue
        default: return .teal
        }
    }

    // MARK: - Selected Day Section
    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedDay(selectedDate))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(formattedMonthYear(selectedDate))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                let count = todosForDay(selectedDate).count
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue, in: Capsule())
                }

                Button(action: { showingAddTodo = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Divider().padding(.horizontal, 16)

            let todos = todosForDay(selectedDate)
            if todos.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.blue.opacity(0.4))
                        Text(localizer.localizedString(forKey: "no_tasks_relax"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(todos) { todo in
                        NavigationLink(destination: TodoDetailView(todo: todo).environmentObject(todoStore)) {
                            todoRow(todo)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer(minLength: 12)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 5)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func todoRow(_ todo: TodoItem) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(priorityColor(todo))
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let due = todo.dueDate {
                    Text(due, style: .time)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if todo.isOverdue {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.red)
                    .font(.system(size: 14))
            } else if todo.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.yellow)
                    .font(.system(size: 13))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(0.5))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func priorityColor(_ todo: TodoItem) -> Color {
        if todo.isOverdue { return .red }
        switch todo.priority {
        case .high: return .orange
        case .medium: return .blue
        default: return .teal
        }
    }

    // MARK: - Helpers
    private func changeMonth(by value: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if let newMonth = cal.date(byAdding: .month, value: value, to: currentMonth) {
                currentMonth = newMonth
            }
        }
    }

    private func daysInMonth() -> [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: currentMonth) else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start)
        let offset = (firstWeekday + 5) % 7
        let range = cal.range(of: .day, in: .month, for: currentMonth) ?? 1..<1

        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            days.append(cal.date(bySetting: .day, value: day, of: interval.start))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func todosForDay(_ date: Date) -> [TodoItem] {
        let filtered = todoStore.todos.filter {
            guard let due = $0.dueDate else { return false }
            return cal.isDate(due, inSameDayAs: date) && !$0.isCompleted
        }
        var seenKeys: Set<String> = []
        return filtered.filter { todo in
            let key = "\(todo.title)|\(todo.description)|\(String(todo.dueDate?.timeIntervalSince1970 ?? -1))|\(todo.category?.name ?? "")|\(todo.priority)"
            guard !seenKeys.contains(key) else { return false }
            seenKeys.insert(key)
            return true
        }
    }

    private func monthName(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: localizer.selectedLanguage == "Englisch" ? "en_US" : "de_DE")
        f.dateFormat = "MMMM"
        return f.string(from: date)
    }

    private func yearString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: date)
    }

    private func formattedDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: localizer.selectedLanguage == "Englisch" ? "en_US" : "de_DE")
        f.dateFormat = "EEEE, d."
        return f.string(from: date)
    }

    private func formattedMonthYear(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: localizer.selectedLanguage == "Englisch" ? "en_US" : "de_DE")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}

// MARK: - Calendar Import

private enum ImportTimeRange: String, CaseIterable {
    case week = "1 Woche"
    case month = "1 Monat"
    case year = "1 Jahr"
    case forever = "Für immer"
    case manual = "Manuell"
}

private enum ImportState: Equatable {
    case idle
    case importing
    case success(Int)
    case empty
    case noCalendarsSelected
}

struct CalendarImportView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) private var dismiss

    @State private var eventStore = EKEventStore()
    @State private var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @State private var availableCalendars: [EKCalendar] = []
    @State private var selectedCalendarIDs: Set<String> = []
    @State private var selectedRange: ImportTimeRange = .month
    @State private var manualStart: Date = Date()
    @State private var manualEnd: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var importState: ImportState = .idle
    @State private var showResultBanner = false
    @AppStorage("skipOverdueOnImport") private var skipOverdueOnImport = false

    private var isAccessGranted: Bool {
        if #available(iOS 17.0, *) { return authStatus == .fullAccess }
        return authStatus == .authorized
    }

    private var startDate: Date {
        let today = Calendar.current.startOfDay(for: Date())
        switch selectedRange {
        // EKEventStore lehnt distantPast ab – max. ~4 Jahre; wir nehmen 3 Jahre zurück
        case .forever: return Calendar.current.date(byAdding: .year, value: -3, to: today) ?? today
        case .manual:  return Calendar.current.startOfDay(for: manualStart)
        default:       return today
        }
    }

    private var endDate: Date {
        let cal = Calendar.current
        let now = Date()
        switch selectedRange {
        case .week:    return cal.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
        case .month:   return cal.date(byAdding: .month,      value: 1, to: now) ?? now
        case .year:    return cal.date(byAdding: .year,       value: 1, to: now) ?? now
        // EKEventStore lehnt distantFuture ab – 3 Jahre voraus (insg. ~6 J. → funktioniert in der Praxis)
        case .forever: return cal.date(byAdding: .year,       value: 3, to: now) ?? now
        case .manual:  return cal.date(bySettingHour: 23, minute: 59, second: 59, of: manualEnd) ?? manualEnd
        }
    }

    private var bannerColor: Color {
        switch importState {
        case .success: return .green
        case .empty: return .orange
        case .noCalendarsSelected: return .red
        default: return .blue
        }
    }

    private var bannerIcon: String {
        switch importState {
        case .success: return "checkmark.circle.fill"
        case .empty: return "tray.fill"
        case .noCalendarsSelected: return "exclamationmark.triangle.fill"
        default: return "info.circle.fill"
        }
    }

    private var bannerText: String {
        switch importState {
        case .success(let count): return "\(count) Eintrag\(count == 1 ? "" : "einträge") erfolgreich importiert"
        case .empty: return "Keine neuen Einträge gefunden"
        case .noCalendarsSelected: return "Bitte mindestens einen Kalender auswählen"
        default: return ""
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Form {
                    if !isAccessGranted {
                        Section {
                            Button("Kalender-Zugriff erlauben") {
                                Task { await requestAccess() }
                            }
                        } footer: {
                            Text("BeeFocus benötigt Lesezugriff auf den Kalender, um Einträge zu importieren.")
                        }
                    } else {
                        Section("Zeitraum") {
                            Picker("Zeitraum", selection: $selectedRange) {
                                ForEach(ImportTimeRange.allCases, id: \.self) { range in
                                    Text(range.rawValue).tag(range)
                                }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()

                            if selectedRange == .manual {
                                DatePicker("Von", selection: $manualStart, displayedComponents: [.date])
                                DatePicker("Bis", selection: $manualEnd, in: manualStart..., displayedComponents: [.date])
                            }
                        }

                        Section("Kalender auswählen") {
                            if availableCalendars.isEmpty {
                                HStack {
                                    ProgressView()
                                        .padding(.trailing, 6)
                                    Text("Kalender werden geladen…")
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                ForEach(availableCalendars, id: \.calendarIdentifier) { cal in
                                    let calID = cal.calendarIdentifier
                                    Toggle(isOn: Binding(
                                        get: { selectedCalendarIDs.contains(calID) },
                                        set: { on in
                                            if on { selectedCalendarIDs.insert(calID) }
                                            else { selectedCalendarIDs.remove(calID) }
                                        }
                                    )) {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(Color(cgColor: cal.cgColor))
                                                .frame(width: 12, height: 12)
                                                .shadow(color: Color(cgColor: cal.cgColor).opacity(0.5), radius: 3, x: 0, y: 1)
                                            Text(cal.title)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Result banner (shown above the form's bottom edge)
                if showResultBanner {
                    HStack(spacing: 12) {
                        Image(systemName: bannerIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(bannerText)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(bannerColor.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: bannerColor.opacity(0.45), radius: 16, x: 0, y: 6)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.78), value: showResultBanner)
            .navigationTitle("Aus Kalender importieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
                if isAccessGranted {
                    ToolbarItem(placement: .confirmationAction) {
                        if importState == .importing {
                            ProgressView()
                        } else {
                            Button("Importieren") {
                                performImport()
                            }
                            .fontWeight(.semibold)
                            .disabled(selectedCalendarIDs.isEmpty)
                        }
                    }
                }
            }
            .task { await requestAccess() }
        }
    }

    private func requestAccess() async {
        if isAccessGranted { loadCalendars(); return }
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }
            authStatus = EKEventStore.authorizationStatus(for: .event)
            if granted { loadCalendars() }
        } catch {
            print("❌ Kalender-Zugriff Fehler: \(error)")
        }
    }

    private func loadCalendars() {
        availableCalendars = eventStore.calendars(for: .event)
        selectedCalendarIDs = Set(availableCalendars.map { $0.calendarIdentifier })
    }

    private func performImport() {
        guard importState != .importing else { return }

        let cals = availableCalendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        guard !cals.isEmpty else {
            showBanner(state: .noCalendarsSelected, autoDismiss: false)
            return
        }

        importState = .importing

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: cals)
        let events = eventStore.events(matching: predicate)

        // Primär: gespeicherter calendarEventIdentifier
        let existingByID = Set(todoStore.todos.compactMap { $0.calendarEventIdentifier })
        let dismissedByID = Set((UserDefaults.standard.array(forKey: "dismissedCalendarEventIDs") as? [String]) ?? [])

        // Sekundär: Titel (normalisiert) + Tag als Fallback gegen Duplikate
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "yyyy-MM-dd"
        let existingByKey: Set<String> = Set(todoStore.todos.compactMap { todo -> String? in
            guard let d = todo.dueDate else { return nil }
            return "\(todo.title.lowercased().trimmingCharacters(in: .whitespaces))|\(dayFmt.string(from: d))"
        })

        let now = Date()
        var count = 0
        for event in events {
            if skipOverdueOnImport && event.startDate < now { continue }

            // Duplikat-Check: Identifier ODER Titel+Tag bereits vorhanden; gelöschte überspringen
            let dayKey = "\((event.title ?? "").lowercased().trimmingCharacters(in: .whitespaces))|\(dayFmt.string(from: event.startDate))"
            guard !existingByID.contains(event.eventIdentifier),
                  !dismissedByID.contains(event.eventIdentifier),
                  !existingByKey.contains(dayKey) else { continue }

            let todo = TodoItem(
                title: event.title ?? "Kalendereintrag",
                description: event.notes ?? "",
                dueDate: event.startDate,
                calendarEventIdentifier: event.eventIdentifier,
                calendarEnabled: false
            )
            todoStore.todos.append(todo)
            count += 1
        }

        if count > 0 {
            todoStore.saveTodos()
            WidgetDataManager.shared.saveTodos(todoStore.todos)
            showBanner(state: .success(count), autoDismiss: true)
        } else {
            showBanner(state: .empty, autoDismiss: false)
        }
    }

    private func showBanner(state: ImportState, autoDismiss: Bool) {
        importState = state
        withAnimation { showResultBanner = true }

        if autoDismiss {
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { dismiss() }
            }
        } else {
            Task {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                await MainActor.run {
                    withAnimation { showResultBanner = false }
                    importState = .idle
                }
            }
        }
    }
}

// MARK: - Todo Detail View
struct TodoDetailView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var localizer = LocalizationManager.shared
    @State private var isCompleted: Bool
    @State private var isEditing = false
    let todo: TodoItem

    init(todo: TodoItem) {
        self.todo = todo
        _isCompleted = State(initialValue: todo.isCompleted)
    }

    private var currentTodo: TodoItem {
        todoStore.todos.first(where: { $0.id == todo.id }) ?? todo
    }

    private var accentBlue: Color { .blue }
    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0.14, green: 0.16, blue: 0.26) : Color(red: 0.97, green: 0.99, blue: 1.0)
    }

    private var dueStatus: (icon: String, text: String, color: Color)? {
        guard !isCompleted, let dueDate = currentTodo.dueDate else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let due = Calendar.current.startOfDay(for: dueDate)
        if due < today {
            return ("exclamationmark.triangle.fill", localizer.localizedString(forKey: "overdue"), .red)
        } else if due == today {
            return ("clock.badge.exclamationmark", localizer.localizedString(forKey: "due_today"), .orange)
        } else if due <= Calendar.current.date(byAdding: .day, value: 2, to: today) ?? today {
            return ("hourglass", localizer.localizedString(forKey: "due_soon"), .orange)
        }
        return nil
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [accentBlue.opacity(0.10), cardBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Title card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            Text(currentTodo.title)
                                .font(.title2.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(4)
                            Spacer()
                            Button(action: toggleCompletion) {
                                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                    .resizable()
                                    .frame(width: 34, height: 34)
                                    .foregroundStyle(isCompleted ? Color.green : Color.secondary.opacity(0.5))
                                    .shadow(color: isCompleted ? Color.green.opacity(0.2) : .clear, radius: 6)
                            }
                        }

                        if let dueDate = currentTodo.dueDate {
                            HStack(spacing: 6) {
                                if let status = dueStatus {
                                    Image(systemName: status.icon).foregroundStyle(status.color)
                                    Text(status.text).foregroundStyle(status.color).font(.subheadline.bold())
                                }
                                Text(dueDate.formatted(.dateTime.day().month().year()))
                                    .foregroundStyle(.secondary).font(.subheadline)
                            }
                        } else if isCompleted {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal").foregroundStyle(Color.green)
                                Text(localizer.localizedString(forKey: "completed_exclaim"))
                                    .font(.subheadline.bold()).foregroundStyle(Color.green)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)

                    // Description card
                    VStack(alignment: .leading, spacing: 10) {
                        Label(localizer.localizedString(forKey: "details"), systemImage: "text.alignleft")
                            .font(.headline)
                        Text(currentTodo.description.isEmpty ? localizer.localizedString(forKey: "no_further_details") : currentTodo.description)
                            .font(.body)
                            .foregroundStyle(currentTodo.description.isEmpty ? Color.secondary : Color.primary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)

                    // Subtasks card
                    if !currentTodo.subTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(localizer.localizedString(forKey: "subtasks"), systemImage: "list.bullet")
                                .font(.headline)
                            ForEach(currentTodo.subTasks) { sub in
                                HStack(spacing: 10) {
                                    Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(sub.isCompleted ? Color.green : Color.secondary)
                                    Text(sub.title).foregroundStyle(.primary)
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 7, x: 0, y: 3)
                    }

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 44)
            }
        }
        .navigationTitle(localizer.localizedString(forKey: "task"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditTodoView(todo: currentTodo)
                .environmentObject(todoStore)
        }
    }

    private func toggleCompletion() {
        var updated = todo
        updated.isCompleted.toggle()
        updated.completedAt = updated.isCompleted ? Date() : nil
        updated.updatedAt = Date()
        todoStore.updateTodo(updated)
        isCompleted = updated.isCompleted
    }
}

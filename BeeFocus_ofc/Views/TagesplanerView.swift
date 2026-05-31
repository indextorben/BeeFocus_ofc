import SwiftUI

// MARK: - TagesplanerView

struct TagesplanerView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("filterCurrentMonthOnly") private var filterCurrentMonthOnly = false
    @AppStorage("collapsedSectionsString") private var collapsedSectionsString: String = ""

    @State private var selectedDate: Date
    @State private var planningTodo: TodoItem? = nil
    @State private var showingAddTodo = false
    @State private var showingQuickAdd = false
    @State private var showingAufgabenUebersicht = false
    @State private var collapsedGroups: Set<String> = []
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var now: Date = Date()
    @State private var showingBausteinPicker = false
    @State private var showingKITagesplan = false
    @State private var draggingID: UUID? = nil
    @State private var dragDelta: CGFloat = 0
    @State private var lastSnappedDelta: Int = 0
    @State private var resizingID: UUID? = nil
    @State private var resizeDelta: CGFloat = 0
    @State private var lastSnappedResizeDelta: Int = 0

    init(initialDate: Date = Date()) {
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: initialDate))
    }

    var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }
    private var cal: Calendar { Calendar.current }
    private var isToday: Bool { cal.isDateInToday(selectedDate) }

    // MARK: - Body

    var body: some View {
        ZStack {
            ThemeBackgroundView()
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
                .scrollDisabled(draggingID != nil || resizingID != nil)
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
        .onReceive(Timer.publish(every: 10, on: .main, in: .common).autoconnect()) { _ in
            now = Date()
        }
        .navigationTitle(selectedDateString)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                NavigationLink {
                    CalendarView().environmentObject(todoStore)
                } label: {
                    Image(systemName: "calendar.badge.clock")
                }
                Button { showingBausteinPicker = true } label: {
                    Image(systemName: "square.stack.fill")
                }
                Menu {
                    Button {
                        if let url = buildDayPDF() { shareItems = [url]; showingShareSheet = true }
                    } label: {
                        Label("Tag als PDF", systemImage: "doc.fill")
                    }
                    Button {
                        if let url = buildWeekPDF() { shareItems = [url]; showingShareSheet = true }
                    } label: {
                        Label("Woche als PDF", systemImage: "doc.on.doc.fill")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                Button { showingQuickAdd = true } label: {
                    Image(systemName: "plus").fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingQuickAdd) {
            TagesplanQuickAddSheet(themeC1: themeC1, themeC2: themeC2) { title, date, endDateRaw in
                let dueDate: Date?
                let endDate: Date?
                if let d = date {
                    let comps = cal.dateComponents([.hour, .minute], from: d)
                    dueDate = cal.date(bySettingHour: comps.hour ?? 9,
                                       minute: comps.minute ?? 0,
                                       second: 0, of: selectedDate)
                    if let e = endDateRaw {
                        let eComps = cal.dateComponents([.hour, .minute], from: e)
                        endDate = cal.date(bySettingHour: eComps.hour ?? 10,
                                            minute: eComps.minute ?? 0,
                                            second: 0, of: selectedDate)
                    } else {
                        endDate = nil
                    }
                } else {
                    dueDate = nil
                    endDate = nil
                }
                let todo = TodoItem(title: title, dueDate: dueDate, endDate: endDate)
                todoStore.addTodo(todo)
            } onAufgabenUebersicht: {
                showingQuickAdd = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showingAufgabenUebersicht = true
                }
            }
        }
        .sheet(isPresented: $showingAufgabenUebersicht) {
            AufgabenUebersichtSheet(themeC1: themeC1, themeC2: themeC2) { todo in
                planningTodo = todo
            }
            .environmentObject(todoStore)
        }
        .sheet(isPresented: $showingAddTodo) {
            AddTodoView().environmentObject(todoStore)
        }
        .sheet(item: $planningTodo) { todo in
            EinplanenSheet(
                todo: todo,
                onSave: { updated in
                    todoStore.updateTodo(updated)
                    planningTodo = nil
                },
                onDelete: {
                    todoStore.deleteTodo(todo)
                    planningTodo = nil
                }
            )
            .environmentObject(todoStore)
        }
        .sheet(isPresented: $showingBausteinPicker) {
            BausteinPickerSheet(datum: selectedDate) { baustein in
                todoStore.addTodo(baustein.todoItem(fuer: selectedDate))
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: shareItems)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showingKITagesplan) {
            if #available(iOS 26.0, *) {
                KITagesplanSheet(
                    todos: todoStore.todos,
                    selectedDate: selectedDate,
                    themeC1: themeC1,
                    themeC2: themeC2
                )
                .environmentObject(todoStore)
            }
        }
    }

    // MARK: - Selected date label

    private var selectedDateString: String {
        if isToday { return "Heute" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, d. MMM"
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: selectedDate)
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        let weekDays = currentWeekDays()
        return HStack(spacing: 0) {
            // Previous week arrow
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
                ForEach(weekDays, id: \.self) { day in
                    let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
                    let isTodayDay = cal.isDateInToday(day)
                    let dayNum = cal.component(.day, from: day)
                    let weekdayStr = shortWeekday(day)

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedDate = day
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text(weekdayStr)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : (isDark ? .white.opacity(0.5) : .secondary))
                            ZStack {
                                Circle()
                                    .fill(isSelected
                                          ? AnyShapeStyle(LinearGradient(colors: [themeC1, themeC2], startPoint: .top, endPoint: .bottom))
                                          : (isTodayDay ? AnyShapeStyle(themeC1.opacity(0.15)) : AnyShapeStyle(Color.clear)))
                                    .frame(width: 30, height: 30)
                                Text("\(dayNum)")
                                    .font(.system(size: 13, weight: isSelected || isTodayDay ? .bold : .regular))
                                    .foregroundStyle(isSelected ? .white : (isDark ? .white.opacity(0.85) : .primary))
                            }
                            // Dot if has tasks
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

            // Next week arrow
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

    private func currentWeekDays() -> [Date] {
        var cal2 = Calendar(identifier: .gregorian)
        cal2.firstWeekday = 2 // Monday
        let weekStart = cal2.date(from: cal2.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
        return (0..<7).compactMap { cal2.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func shortWeekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEE"
        let s = f.string(from: date)
        return String(s.prefix(2))
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        let done = todoStore.todos.filter {
            $0.isCompleted && ($0.completedAt.map { cal.isDate($0, inSameDayAs: selectedDate) } == true)
        }.count
        let total = todoStore.todos.filter {
            $0.dueDate.map { cal.isDate($0, inSameDayAs: selectedDate) } == true
        }.count
        let prog = total > 0 ? Double(done) / Double(total) : 0.0

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
                Text(headerLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                Text(total == 0
                     ? "Keine Aufgaben eingeplant"
                     : "\(done) von \(total) erledigt")
                    .font(.caption)
                    .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
            }
            Spacer()

            VStack(spacing: 6) {
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
                Button {
                    showingKITagesplan = true
                } label: {
                    Label("KI", systemImage: "sparkles")
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

    private var headerLabel: String {
        if isToday {
            let h = cal.component(.hour, from: Date())
            if h < 12 { return "Guten Morgen" }
            if h < 18 { return "Guten Mittag" }
            return "Guten Abend"
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE"
        return f.string(from: selectedDate)
    }

    // MARK: - Calendar Timeline

    // MARK: - Tree Timeline

    // 1 pt per minute → 1h = 60pt, capped at 90pt per gap
    private let minsPerPt: CGFloat = 1.0

    private var treeTimeline: some View {
        let midStart = cal.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let eveStart = cal.date(bySettingHour: 18, minute: 0, second: 0, of: selectedDate) ?? selectedDate

        // Find tasks from earlier sections whose endDate reaches into the next section
        let morningTasks = tasksForHours(6..<12)
        let middayTasks  = tasksForHours(12..<18)

        let spanToMidday  = morningTasks.last(where: { $0.endDate.map { $0 > midStart } == true })
        let spanToEvening = (morningTasks + middayTasks).last(where: { $0.endDate.map { $0 > eveStart } == true })

        return VStack(spacing: 0) {
            treeSection(label: "Morgen", icon: "sun.and.horizon.fill", color: .orange,  hours: 6..<12,  spanningIn: nil)
            treeSection(label: "Mittag", icon: "sun.max.fill",         color: themeC1,  hours: 12..<18, spanningIn: spanToMidday)
            treeSection(label: "Abend",  icon: "moon.stars.fill",      color: .indigo,  hours: 18..<24, spanningIn: spanToEvening)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func treeSection(label: String, icon: String, color: Color, hours: Range<Int>, spanningIn: TodoItem?) -> some View {
        let tasks = tasksForHours(hours)
        let sectionStart = cal.date(bySettingHour: hours.lowerBound, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let sectionEnd: Date = {
            if hours.upperBound == 24 {
                return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: selectedDate)) ?? selectedDate
            }
            return cal.date(bySettingHour: hours.upperBound, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        }()
        let effectiveStart: Date = spanningIn?.endDate ?? sectionStart
        let nowInSection = isToday && now >= sectionStart && now < sectionEnd
        // If the spanning-in task itself covers now, its overlay handles the indicator —
        // suppress the row-based indicator for this section.
        let spanningCoversNow = nowInSection
            && (spanningIn?.dueDate.map { now >= $0 } ?? false)
            && (spanningIn?.endDate.map { now < $0 } ?? false)
        let nowInSectionEff = nowInSection && !spanningCoversNow

        // Where should nowIndicatorRow be inserted?
        // nowIdx == -1            → not today / section doesn't contain now
        // nowIdx == -2            → now is inside a duration block (overlay handles it)
        // nowIdx == i             → before tasks[i]
        // nowIdx == tasks.count   → after all tasks (or no tasks)
        let nowIdx: Int = {
            guard nowInSectionEff else { return -1 }
            for (i, task) in tasks.enumerated() {
                let due = task.dueDate ?? .distantFuture
                let end = task.endDate ?? due
                if now < due { return i }
                if now < end {
                    let hasDur = task.endDate.map { $0 > (task.dueDate ?? .distantPast) } == true
                    return hasDur ? -2 : i + 1
                }
            }
            return tasks.count
        }()

        VStack(spacing: 0) {
            if spanningIn == nil {
                treeSectionHeader(label: label, icon: icon, color: color)
            }

            if tasks.isEmpty {
                if nowInSectionEff { nowIndicatorRow() }
                let mins = CGFloat(max(sectionEnd.timeIntervalSince(effectiveStart) / 60, 0))
                if mins > 5 { freeTimeRow(minutes: mins, color: color, showHint: spanningIn == nil) }
            } else {
                // Gap before first task
                let preGap = CGFloat(max((tasks[0].dueDate ?? sectionEnd).timeIntervalSince(effectiveStart) / 60, 0))
                if preGap > 5 { freeTimeRow(minutes: preGap, color: color, showHint: false) }

                if nowIdx == 0 { nowIndicatorRow() }

                ForEach(Array(tasks.enumerated()), id: \.element.id) { idx, task in
                    let isDragging = draggingID == task.id
                    let deltaMins = isDragging ? Int((dragDelta / minsPerPt).rounded()) : 0
                    let snappedDelta = Int((Double(deltaMins) / 15.0).rounded()) * 15
                    let snappedPixels = CGFloat(snappedDelta) * minsPerPt
                    let isResizing = resizingID == task.id
                    let resizeSnapMins = isResizing ? Int((Double(Int((resizeDelta / minsPerPt).rounded())) / 15.0).rounded()) * 15 : 0
                    let resizeExtraPt = CGFloat(resizeSnapMins) * minsPerPt
                    taskTreeRow(task: task, flipSide: idx % 2 == 0, isNowSection: nowInSectionEff, isDragging: isDragging, isResizing: isResizing, resizeExtraPt: resizeExtraPt, resizeSnapMins: resizeSnapMins)
                        .scaleEffect(isDragging ? 1.02 : 1.0, anchor: .center)
                        .shadow(color: isDragging ? themeC1.opacity(0.3) : .clear, radius: 12, x: 0, y: 5)
                        .offset(y: isDragging ? dragDelta : 0)
                        .zIndex(isDragging ? 10 : (isResizing ? 9 : 0))
                        .overlay(alignment: .topLeading) {
                            if isDragging && snappedDelta != 0, let target = dragTargetDate(for: task) {
                                let cal = Calendar.current
                                let h = cal.component(.hour, from: target)
                                let m = cal.component(.minute, from: target)
                                HStack(spacing: 0) {
                                    Text(String(format: "%02d:%02d", h, m))
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(themeC1)
                                        .frame(width: 44, alignment: .trailing)
                                        .padding(.trailing, 8)
                                    ZStack {
                                        Circle().fill(themeC1.opacity(0.25)).frame(width: 14, height: 14)
                                        Circle().fill(themeC1).frame(width: 7, height: 7)
                                    }
                                    .frame(width: 20)
                                    Rectangle()
                                        .fill(LinearGradient(colors: [themeC1, themeC1.opacity(0)],
                                                             startPoint: .leading, endPoint: .trailing))
                                        .frame(height: 2)
                                        .padding(.leading, 8)
                                }
                                .frame(maxWidth: .infinity)
                                .offset(y: snappedPixels)
                                .animation(.spring(response: 0.15, dampingFraction: 0.8), value: snappedPixels)
                                .allowsHitTesting(false)
                            }
                        }
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
                        .animation(.spring(response: 0.2, dampingFraction: 0.85), value: isResizing)
                        .overlay {
                            TaskDragOverlay(
                                minsPerPt: minsPerPt,
                                draggingID: $draggingID,
                                dragDelta: $dragDelta,
                                lastSnappedDelta: $lastSnappedDelta,
                                taskID: task.id
                            ) { snappedMins in
                                guard snappedMins != 0, let due = task.dueDate else { return }
                                var updated = task
                                updated.dueDate = due.addingTimeInterval(Double(snappedMins) * 60)
                                if let end = task.endDate {
                                    updated.endDate = end.addingTimeInterval(Double(snappedMins) * 60)
                                }
                                todoStore.updateTodo(updated)
                            }
                        }

                    if nowIdx == idx + 1 { nowIndicatorRow() }

                    if idx + 1 < tasks.count {
                        let gapStart = task.endDate ?? task.dueDate ?? sectionEnd
                        let gapEnd   = tasks[idx + 1].dueDate ?? sectionEnd
                        let gapMins  = CGFloat(max(gapEnd.timeIntervalSince(gapStart) / 60, 0))
                        if gapMins > 5 { freeTimeRow(minutes: gapMins, color: color, showHint: false) }
                    }
                }

                if nowIdx == tasks.count { nowIndicatorRow() }

                // Gap after last task
                if let lastTask = tasks.last {
                    let lastEnd  = lastTask.endDate ?? lastTask.dueDate ?? sectionEnd
                    let postGap  = CGFloat(max(sectionEnd.timeIntervalSince(lastEnd) / 60, 0))
                    if postGap > 5 { freeTimeRow(minutes: postGap, color: color, showHint: false) }
                }
            }
        }
    }

    // Current-time indicator row — aligned to the spine
    @ViewBuilder
    private func nowIndicatorRow() -> some View {
        let timeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
        HStack(spacing: 0) {
            Text(timeFmt.string(from: now))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(themeC1)
                .frame(width: 44, alignment: .trailing)
                .padding(.trailing, 8)

            ZStack {
                Circle()
                    .fill(themeC1.opacity(0.2))
                    .frame(width: 18, height: 18)
                Circle()
                    .fill(themeC1)
                    .frame(width: 9, height: 9)
            }
            .frame(width: 20)

            Rectangle()
                .fill(
                    LinearGradient(colors: [themeC1, themeC1.opacity(0)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(height: 1.5)
                .padding(.leading, 10)
                .padding(.trailing, 4)
        }
        .padding(.vertical, 4)
        .id("nowIndicator")
    }

    // Section header: aligns with the timeline spine
    private func treeSectionHeader(label: String, icon: String, color: Color) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Spacer().frame(width: 52) // time column (44) + gap (8)

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

    // Task row — time left (44pt), spine center (20pt), card right
    private func taskTreeRow(task: TodoItem, flipSide: Bool, isNowSection: Bool = false, isDragging: Bool = false, isResizing: Bool = false, resizeExtraPt: CGFloat = 0, resizeSnapMins: Int = 0) -> some View {
        let hasDuration = task.endDate.map { $0 > (task.dueDate ?? .distantPast) } == true
        let durationMins: CGFloat = hasDuration
            ? CGFloat(task.endDate!.timeIntervalSince(task.dueDate!) / 60)
            : 0
        let lineColor = isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
        let timeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
        let isActive = isToday && !task.isCompleted
            && (task.dueDate.map { now >= $0 } ?? false)
            && (task.endDate.map { now < $0 } ?? false)

        return HStack(alignment: .top, spacing: 0) {
            // Time label
            Group {
                if !isDragging, let due = task.dueDate {
                    Text(timeFmt.string(from: due))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(task.isCompleted ? .secondary : themeC1)
                } else {
                    Color.clear
                }
            }
            .frame(width: 44, alignment: .trailing)
            .padding(.trailing, 8)
            .padding(.top, 10)

            // Spine: dot + continuing line
            VStack(spacing: 0) {
                ZStack {
                    if task.isCompleted {
                        Circle()
                            .fill(Color.green.opacity(0.25))
                            .frame(width: 14, height: 14)
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Color.green)
                    } else if isActive {
                        Circle()
                            .fill(themeC1.opacity(0.2))
                            .frame(width: 16, height: 16)
                        Circle()
                            .fill(themeC1)
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .fill(hasDuration ? themeC1 : themeC1.opacity(0.6))
                            .frame(width: hasDuration ? 11 : 9, height: hasDuration ? 11 : 9)
                    }
                }
                .padding(.top, 8)
                Rectangle()
                    .fill(lineColor)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)

            // Card
            taskTreeCard(task, hasDuration: hasDuration, durationMins: durationMins, isActive: isActive, isResizing: isResizing, resizeExtraPt: resizeExtraPt, resizeSnapMins: resizeSnapMins)
                .padding(.leading, 10)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)
        }
        .opacity(task.isCompleted ? 0.55 : 1.0)
        .overlay(alignment: .topLeading) {
            if isActive, hasDuration, let due = task.dueDate, let end = task.endDate, now > due, now < end {
                let frac = min(max(CGFloat(now.timeIntervalSince(due) / end.timeIntervalSince(due)), 0), 1)
                GeometryReader { geo in
                    let y = frac * geo.size.height
                    // Time label in the time column (44pt wide, right-aligned)
                    Text(timeFmt.string(from: now))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(themeC1)
                        .frame(width: 44, alignment: .trailing)
                        .offset(x: 0, y: y - 7)
                    // Circle on the spine (spine starts at x=52)
                    ZStack {
                        Circle().fill(themeC1.opacity(0.25)).frame(width: 18, height: 18)
                        Circle().fill(themeC1).frame(width: 9, height: 9)
                    }
                    .offset(x: 52, y: y - 9)
                    // Horizontal line extending from spine into card area
                    Rectangle()
                        .fill(LinearGradient(colors: [themeC1, themeC1.opacity(0)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(geo.size.width - 72, 0), height: 1.5)
                        .offset(x: 72, y: y)
                }
                .allowsHitTesting(false)
            }
        }
    }

    // Free-time gap — aligns with timeline spine
    private func freeTimeRow(minutes: CGFloat, color: Color, showHint: Bool) -> some View {
        let lineColor = isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
        let height = max(min(minutes * minsPerPt, 90), 20)

        return HStack(alignment: .center, spacing: 0) {
            Spacer().frame(width: 52) // matches time col + gap

            Rectangle().fill(lineColor).frame(width: 2, height: height)
                .frame(width: 20)

            if showHint {
                Button { showingQuickAdd = true } label: {
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

    // Task card — compact row or stretched duration block
    private func taskTreeCard(_ todo: TodoItem, hasDuration: Bool, durationMins: CGFloat, isActive: Bool = false, isResizing: Bool = false, resizeExtraPt: CGFloat = 0, resizeSnapMins: Int = 0) -> some View {
        let blockH: CGFloat = hasDuration ? max(durationMins * minsPerPt + resizeExtraPt, 68) : 40
        let timeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
        let isUpcoming = isToday && !todo.isCompleted && (todo.dueDate.map { now < $0 } ?? false)
        let borderColor: Color = todo.isCompleted ? .green.opacity(0.35)
                               : isActive         ? themeC1.opacity(0.6)
                               :                    themeC1.opacity(0.28)
        let bgColor: Color = todo.isCompleted ? .green.opacity(isDark ? 0.08 : 0.05)
                           : isActive         ? themeC1.opacity(isDark ? 0.18 : 0.10)
                           :                   themeC1.opacity(isDark ? 0.12 : 0.07)

        return Group {
            if hasDuration, let endDate = todo.endDate {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(todo.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isDark ? .white.opacity(0.95) : Color.primary)
                            .shadow(color: isDark ? .black.opacity(0.55) : .white.opacity(0.80), radius: 3, x: 0, y: 1)
                            .strikethrough(todo.isCompleted, color: .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                todoStore.toggleTodo(todo)
                            }
                        } label: {
                            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 17))
                                .foregroundStyle(todo.isCompleted ? Color.green : themeC1.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 4)
                    HStack(alignment: .bottom) {
                        HStack(spacing: 4) {
                            if isActive {
                                Circle().fill(themeC1).frame(width: 5, height: 5)
                                Text("läuft")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(themeC1)
                            }
                            Text("bis \(timeFmt.string(from: endDate))")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            if isActive {
                                Text("·")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "timer")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(themeC1)
                                Text(remainingTimeLabel(until: endDate))
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(themeC1)
                                    .contentTransition(.numericText())
                                    .animation(.easeInOut(duration: 0.3), value: remainingTimeLabel(until: endDate))
                            } else if isUpcoming, let due = todo.dueDate {
                                Text("·")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "clock")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text("startet in \(startingInLabel(from: due))")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .contentTransition(.numericText())
                                    .animation(.easeInOut(duration: 0.3), value: startingInLabel(from: due))
                            }
                        }
                        Spacer()
                        Button { planningTodo = todo } label: {
                            Image(systemName: "pencil.circle")
                                .font(.system(size: 15))
                                .foregroundStyle(themeC1.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, minHeight: blockH)
                .background {
                    RoundedRectangle(cornerRadius: 11).fill(bgColor)
                    if !aktivesThema.isEmpty {
                        TaskCardThemeDecoration(theme: aktivesThema, isDark: isDark, isActive: isActive)
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                            .allowsHitTesting(false)
                        RoundedRectangle(cornerRadius: 11)
                            .fill(LinearGradient(
                                colors: [
                                    (isDark ? Color.black : Color.white).opacity(0.32),
                                    (isDark ? Color.black : Color.white).opacity(0.14),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: UnitPoint(x: 0.68, y: 0.5)
                            ))
                            .allowsHitTesting(false)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(isResizing ? themeC1.opacity(0.7) : borderColor,
                                lineWidth: isActive || isResizing ? 1.8 : 1.5)
                )
                // Resize handle at bottom
                .overlay(alignment: .bottom) {
                    if !todo.isCompleted {
                        resizeHandleBar(isResizing: isResizing)
                            .overlay {
                                TaskResizeHandle(
                                    minsPerPt: minsPerPt,
                                    resizingID: $resizingID,
                                    resizeDelta: $resizeDelta,
                                    lastSnappedResizeDelta: $lastSnappedResizeDelta,
                                    taskID: todo.id,
                                    currentEndDate: todo.endDate,
                                    currentStartDate: todo.dueDate
                                ) { snappedMins in
                                    guard snappedMins != 0, let end = todo.endDate,
                                          let due = todo.dueDate else { return }
                                    let newEnd = end.addingTimeInterval(Double(snappedMins) * 60)
                                    guard newEnd >= due.addingTimeInterval(15 * 60) else { return }
                                    var updated = todo
                                    updated.endDate = newEnd
                                    todoStore.updateTodo(updated)
                                }
                            }
                    }
                }
                // End-time bubble shown while resizing
                .overlay(alignment: .bottomTrailing) {
                    if isResizing, let end = todo.endDate {
                        let newEnd = end.addingTimeInterval(Double(resizeSnapMins) * 60)
                        let fmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.to.line")
                                .font(.system(size: 9, weight: .bold))
                            Text(fmt.string(from: newEnd))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeC1, in: Capsule())
                        .padding(.trailing, 8)
                        .padding(.bottom, 28)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: resizeSnapMins)
                    }
                }

            } else {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            todoStore.toggleTodo(todo)
                        }
                    } label: {
                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 17))
                            .foregroundStyle(todo.isCompleted ? Color.green : themeC1.opacity(0.5))
                    }
                    .buttonStyle(.plain)

                    Text(todo.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isDark ? .white.opacity(0.95) : Color.primary)
                        .shadow(color: isDark ? .black.opacity(0.55) : .white.opacity(0.80), radius: 3, x: 0, y: 1)
                        .strikethrough(todo.isCompleted, color: .secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    if isActive {
                        Circle().fill(themeC1).frame(width: 6, height: 6)
                    } else if isUpcoming, let due = todo.dueDate {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 9, weight: .semibold))
                            Text("in \(startingInLabel(from: due))")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                        }
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: startingInLabel(from: due))
                    }

                    Button { planningTodo = todo } label: {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 15))
                            .foregroundStyle(themeC1.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: blockH)
                .background {
                    RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 10).fill(bgColor)
                    if !aktivesThema.isEmpty {
                        TaskCardThemeDecoration(theme: aktivesThema, isDark: isDark, isActive: isActive)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .allowsHitTesting(false)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(
                                colors: [
                                    (isDark ? Color.black : Color.white).opacity(0.32),
                                    (isDark ? Color.black : Color.white).opacity(0.14),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: UnitPoint(x: 0.68, y: 0.5)
                            ))
                            .allowsHitTesting(false)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderColor, lineWidth: isActive ? 1.5 : 1))
            }
        }
    }

    @ViewBuilder
    private func resizeHandleBar(isResizing: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 24)
                Capsule()
                    .fill(isResizing ? themeC1 : themeC1.opacity(0.40))
                    .frame(width: isResizing ? 52 : 36, height: 4)
                    .shadow(color: isResizing ? themeC1.opacity(0.5) : .clear, radius: 4, x: 0, y: 0)
            }
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle().inset(by: -4))
    }

    private func dragTargetDate(for todo: TodoItem) -> Date? {
        guard draggingID == todo.id, let due = todo.dueDate else { return nil }
        let deltaMins = Int((dragDelta / minsPerPt).rounded())
        let snappedDelta = Int((Double(deltaMins) / 15.0).rounded()) * 15
        return due.addingTimeInterval(Double(snappedDelta) * 60)
    }

    private func remainingTimeLabel(until endDate: Date) -> String {
        let secs = max(0, endDate.timeIntervalSince(now))
        let mins = Int(secs / 60)
        if mins == 0 { return "< 1min" }
        if mins < 60 { return "\(mins)min" }
        let h = mins / 60; let m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)min"
    }

    private func startingInLabel(from dueDate: Date) -> String {
        let secs = max(0, dueDate.timeIntervalSince(now))
        let mins = Int(secs / 60)
        if mins < 15 { return "gleich" }
        if mins < 60 { return "\(mins)min" }
        let h = mins / 60; let m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)min"
    }

    private func tasksForHours(_ hours: Range<Int>) -> [TodoItem] {
        todoStore.todos.filter { todo in
            guard let due = todo.dueDate else { return false }
            guard cal.isDate(due, inSameDayAs: selectedDate) else { return false }
            return hours.contains(cal.component(.hour, from: due))
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    // MARK: - Alle Aufgaben (collapsible groups)

    private var alleAufgabenContent: some View {
        VStack(spacing: 12) {
            aufgabenGroup(id: "today", title: "Heute", icon: "sun.max.fill",
                          color: themeC1, todos: groupedTodos(.today))
            aufgabenGroup(id: "overdue", title: "Überfällig", icon: "exclamationmark.triangle.fill",
                          color: .red, todos: groupedTodos(.overdue))
            aufgabenGroup(id: "week", title: "Diese Woche", icon: "calendar.badge.clock",
                          color: themeC2, todos: groupedTodos(.thisWeek))
            aufgabenGroup(id: "later", title: "Später", icon: "arrow.right.circle.fill",
                          color: .secondary, todos: groupedTodos(.later))
            aufgabenGroup(id: "nodate", title: "Ohne Datum", icon: "tray.fill",
                          color: .secondary, todos: groupedTodos(.noDate))
        }
    }

    private enum TaskGroupKind { case today, overdue, thisWeek, later, noDate }

    private func groupedTodos(_ kind: TaskGroupKind) -> [TodoItem] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekEnd = cal.date(byAdding: .day, value: 7, to: today) ?? today
        return todoStore.todos.filter { todo in
            guard !todo.isCompleted else { return false }
            switch kind {
            case .today:    return todo.dueDate.map { cal.isDateInToday($0) } == true
            case .overdue:  return todo.dueDate.map { $0 < today } == true
            case .thisWeek:
                guard let d = todo.dueDate else { return false }
                return d > today && d <= weekEnd && !cal.isDateInToday(d)
            case .later:    return todo.dueDate.map { $0 > weekEnd } == true
            case .noDate:   return todo.dueDate == nil
            }
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    @ViewBuilder
    private func aufgabenGroup(id: String, title: String, icon: String, color: Color, todos: [TodoItem]) -> some View {
        if !todos.isEmpty {
            let collapsed = collapsedGroups.contains(id)
            VStack(spacing: 0) {
                // Header
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        if collapsed { collapsedGroups.remove(id) }
                        else { collapsedGroups.insert(id) }
                    }
                } label: {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: 3, height: 26)

                        ZStack {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(color.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(color)
                        }

                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isDark ? .white : .primary)

                        Spacer()

                        Text("\(todos.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(color.opacity(0.12), in: Capsule())

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(collapsed ? 0 : 90))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                if !collapsed {
                    Divider().opacity(0.2).padding(.horizontal, 14)

                    VStack(spacing: 0) {
                        ForEach(todos) { todo in
                            planningRow(todo, color: color)
                            if todo.id != todos.last?.id {
                                Divider().opacity(0.1).padding(.leading, 54)
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
            .themeGlass(cornerRadius: 16)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: collapsed)
        }
    }

    private func planningRow(_ todo: TodoItem, color: Color) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    todoStore.toggleTodo(todo)
                }
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(color.opacity(0.5))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)
                    .lineLimit(1)
                if let due = todo.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(due, style: .date)
                        if Calendar.current.component(.hour, from: due) > 0 {
                            Text("·")
                            Text(due, format: .dateTime.hour().minute())
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(color.opacity(0.75))
                }
            }

            Spacer()

            Button { planningTodo = todo } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock.badge.plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Einplanen")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(themeC1)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(themeC1.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - PDF Export

    @MainActor
    private func buildDayPDF() -> URL? {
        let view = TagesplanExportView(
            date: selectedDate, todos: todoStore.todos, themeC1: themeC1, themeC2: themeC2
        )
        return renderToPDF(view: view, filename: "BeeFocus_Tagesplan")
    }

    @MainActor
    private func buildWeekPDF() -> URL? {
        let days = currentWeekDays()
        var cal2 = Calendar(identifier: .gregorian); cal2.firstWeekday = 2
        let kw = cal2.component(.weekOfYear, from: selectedDate)
        let view = TagesplanWocheExportView(
            days: days, todos: todoStore.todos, themeC1: themeC1, themeC2: themeC2, kw: kw
        )
        return renderToPDF(view: view, filename: "BeeFocus_Wochenplan_KW\(kw)")
    }

    @MainActor
    private func renderToPDF<V: View>(view: V, filename: String) -> URL? {
        let a4W: CGFloat = 595, a4H: CGFloat = 842, margin: CGFloat = 36
        let contentW = a4W - margin * 2

        let renderer = ImageRenderer(content:
            view.frame(width: contentW).environment(\.colorScheme, .light)
        )
        renderer.scale = 2.0
        guard let image = renderer.uiImage, let cgImg = image.cgImage else { return nil }

        let contentH = a4H - margin * 2
        let scale = image.scale
        let totalH = image.size.height

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: a4W, height: a4H))
        let data = pdfRenderer.pdfData { ctx in
            var yOffset: CGFloat = 0
            while yOffset < totalH {
                ctx.beginPage()
                let sliceH = min(contentH, totalH - yOffset)
                let cropRect = CGRect(
                    x: 0, y: yOffset * scale,
                    width: image.size.width * scale,
                    height: sliceH * scale
                )
                if let slice = cgImg.cropping(to: cropRect) {
                    let sliceImg = UIImage(cgImage: slice, scale: scale, orientation: .up)
                    sliceImg.draw(in: CGRect(x: margin, y: margin, width: contentW, height: sliceH))
                }
                yOffset += contentH
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filename).pdf")
        try? data.write(to: url)
        return url
    }

}

// MARK: - Task Drag Overlay (UIKit-backed for smooth long-press drag in ScrollView)

private struct TaskDragOverlay: UIViewRepresentable {
    let minsPerPt: CGFloat
    @Binding var draggingID: UUID?
    @Binding var dragDelta: CGFloat
    @Binding var lastSnappedDelta: Int
    let taskID: UUID
    let onCommit: (_ snappedMins: Int) -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        let lp = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handle(_:))
        )
        lp.minimumPressDuration = 0.45
        lp.allowableMovement = 10
        lp.cancelsTouchesInView = false
        v.addGestureRecognizer(lp)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        // Disable recognizer on non-active cards while a drag is in progress
        uiView.gestureRecognizers?.forEach {
            $0.isEnabled = draggingID == nil || draggingID == taskID
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: TaskDragOverlay
        private var startY: CGFloat = 0

        init(_ parent: TaskDragOverlay) { self.parent = parent }

        @objc func handle(_ gr: UILongPressGestureRecognizer) {
            switch gr.state {
            case .began:
                guard parent.draggingID == nil else { return }
                startY = gr.location(in: nil).y
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                parent.lastSnappedDelta = 0
                parent.draggingID = parent.taskID

            case .changed:
                guard parent.draggingID == parent.taskID else { return }
                let dy = gr.location(in: nil).y - startY
                parent.dragDelta = dy
                let snap = Self.snapMins(dy, minsPerPt: parent.minsPerPt)
                if snap != parent.lastSnappedDelta {
                    parent.lastSnappedDelta = snap
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }

            case .ended, .cancelled, .failed:
                guard parent.draggingID == parent.taskID else { return }
                let dy = gr.location(in: nil).y - startY
                let snap = Self.snapMins(dy, minsPerPt: parent.minsPerPt)
                parent.onCommit(snap)
                parent.lastSnappedDelta = 0
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    parent.draggingID = nil
                    parent.dragDelta = 0
                }

            default: break
            }
        }

        private static func snapMins(_ dy: CGFloat, minsPerPt: CGFloat) -> Int {
            let mins = Int((dy / minsPerPt).rounded())
            return Int((Double(mins) / 15.0).rounded()) * 15
        }
    }
}

// MARK: - Task Resize Handle (zieht nur das Ende / endDate einer Dauerkarte)

private struct TaskResizeHandle: UIViewRepresentable {
    let minsPerPt: CGFloat
    @Binding var resizingID: UUID?
    @Binding var resizeDelta: CGFloat
    @Binding var lastSnappedResizeDelta: Int
    let taskID: UUID
    let currentEndDate: Date?
    let currentStartDate: Date?
    let onCommit: (_ snappedMins: Int) -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        let lp = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handle(_:))
        )
        lp.minimumPressDuration = 0.28
        lp.allowableMovement = 12
        lp.cancelsTouchesInView = false
        v.addGestureRecognizer(lp)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        uiView.gestureRecognizers?.forEach {
            $0.isEnabled = resizingID == nil || resizingID == taskID
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: TaskResizeHandle
        private var startY: CGFloat = 0

        init(_ parent: TaskResizeHandle) { self.parent = parent }

        @objc func handle(_ gr: UILongPressGestureRecognizer) {
            switch gr.state {
            case .began:
                guard parent.resizingID == nil else { return }
                startY = gr.location(in: nil).y
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                parent.lastSnappedResizeDelta = 0
                parent.resizingID = parent.taskID

            case .changed:
                guard parent.resizingID == parent.taskID else { return }
                let dy = gr.location(in: nil).y - startY
                parent.resizeDelta = dy
                let snap = Self.snapMins(dy, minsPerPt: parent.minsPerPt)
                // Clamp: don't shrink below 15 min
                let clampedSnap = clamp(snap, start: parent.currentStartDate, end: parent.currentEndDate)
                if clampedSnap != parent.lastSnappedResizeDelta {
                    parent.lastSnappedResizeDelta = clampedSnap
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }

            case .ended, .cancelled, .failed:
                guard parent.resizingID == parent.taskID else { return }
                let dy = gr.location(in: nil).y - startY
                let snap = Self.snapMins(dy, minsPerPt: parent.minsPerPt)
                let clampedSnap = clamp(snap, start: parent.currentStartDate, end: parent.currentEndDate)
                parent.onCommit(clampedSnap)
                parent.lastSnappedResizeDelta = 0
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    parent.resizingID = nil
                    parent.resizeDelta = 0
                }

            default: break
            }
        }

        private static func snapMins(_ dy: CGFloat, minsPerPt: CGFloat) -> Int {
            let mins = Int((dy / minsPerPt).rounded())
            return Int((Double(mins) / 15.0).rounded()) * 15
        }

        private func clamp(_ snapMins: Int, start: Date?, end: Date?) -> Int {
            guard let s = start, let e = end else { return snapMins }
            let currentDur = e.timeIntervalSince(s) / 60
            let newDur = currentDur + Double(snapMins)
            if newDur < 15 {
                return Int(15 - currentDur)
            }
            return snapMins
        }
    }
}

// MARK: - Activity Share Sheet

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Quick Slot Model

struct QuickSlot: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var icon: String
    var hour: Int
    var minute: Int

    init(id: UUID = UUID(), name: String, icon: String, hour: Int, minute: Int = 0) {
        self.id = id; self.name = name; self.icon = icon; self.hour = hour; self.minute = minute
    }
}

private let defaultQuickSlots: [QuickSlot] = [
    QuickSlot(name: "Morgen",     icon: "sun.and.horizon.fill", hour: 8),
    QuickSlot(name: "Vormittag",  icon: "sun.max",              hour: 10),
    QuickSlot(name: "Mittag",     icon: "sun.max.fill",         hour: 12),
    QuickSlot(name: "Nachmittag", icon: "cloud.sun.fill",       hour: 15),
    QuickSlot(name: "Abend",      icon: "moon.fill",            hour: 18),
    QuickSlot(name: "Spätabend",  icon: "moon.stars.fill",      hour: 21),
]

private func loadQuickSlots() -> [QuickSlot] {
    guard let data = UserDefaults.standard.data(forKey: "quickSlots"),
          let decoded = try? JSONDecoder().decode([QuickSlot].self, from: data) else {
        return defaultQuickSlots
    }
    return decoded
}

private func saveQuickSlots(_ slots: [QuickSlot]) {
    if let data = try? JSONEncoder().encode(slots) {
        UserDefaults.standard.set(data, forKey: "quickSlots")
    }
}


#Preview {
    NavigationStack {
        TagesplanerView()
            .environmentObject(TodoStore())
    }
}
// MARK: - Quick Add Sheet

struct TagesplanQuickAddSheet: View {
    let themeC1: Color
    let themeC2: Color
    let onAdd: (String, Date?, Date?) -> Void
    let onAufgabenUebersicht: () -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var bausteinStore = BausteinStore.shared
    @FocusState private var titleFocused: Bool
    @State private var title: String = ""
    @State private var selectedSlotID: UUID? = nil
    @State private var showingCustom = false
    @State private var showingSlotEditor = false
    @State private var slots: [QuickSlot] = loadQuickSlots()
    @State private var customTimeStart: Date = {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var customTimeEnd: Date = {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var selectedBaustein: TagesplanBaustein? = nil

    var isDark: Bool { colorScheme == .dark }

    private var selectedSlot: QuickSlot? { slots.first { $0.id == selectedSlotID } }

    private var vorschlaege: [TagesplanBaustein] {
        bausteinStore.smartVorschlaege(datum: Date(), eingabe: title)
    }

    private var dueDate: Date? {
        if showingCustom { return customTimeStart }
        guard let s = selectedSlot else { return nil }
        return Calendar.current.date(bySettingHour: s.hour, minute: s.minute, second: 0, of: Date())
    }

    private var timeLabel: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        if showingCustom { return "\(f.string(from: customTimeStart)) – \(f.string(from: customTimeEnd))" }
        guard let s = selectedSlot else { return "" }
        return String(format: "%02d:%02d", s.hour, s.minute)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (isDark ? Color(red: 0.08, green: 0.08, blue: 0.14) : Color(red: 0.96, green: 0.95, blue: 1.0))
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Title input
                        HStack(spacing: 12) {
                            Image(systemName: "pencil.line").font(.system(size: 18)).foregroundStyle(themeC1)
                            TextField("Aufgabe eingeben…", text: $title)
                                .font(.system(size: 18, weight: .medium))
                                .focused($titleFocused)
                                .submitLabel(.done)
                                .onSubmit { if !title.trimmingCharacters(in: .whitespaces).isEmpty { submit() } }
                                .onChange(of: title) { _ in
                                    if selectedBaustein != nil &&
                                       title != selectedBaustein?.titel { selectedBaustein = nil }
                                }
                            if !title.isEmpty {
                                Button { title = ""; selectedBaustein = nil } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

                        // Smart Vorschläge
                        if !vorschlaege.isEmpty {
                            smartVorschlaegeRow
                        }

                        // Time slots
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Zeitraum")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
                                Spacer()
                                if selectedSlotID != nil || showingCustom {
                                    Text(timeLabel)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(themeC1)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(themeC1.opacity(0.12), in: Capsule())
                                }
                                Button {
                                    showingSlotEditor = true
                                } label: {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 13))
                                        .foregroundStyle(themeC1.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 4)
                            }
                            .padding(.horizontal, 2)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(slots) { slot in
                                    slotButton(slot: slot)
                                }
                                customSlotButton
                            }

                            if showingCustom {
                                HStack(spacing: 0) {
                                    VStack(spacing: 6) {
                                        Text("Von").font(.caption.weight(.semibold))
                                            .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
                                        DatePicker("", selection: $customTimeStart, displayedComponents: .hourAndMinute)
                                            .datePickerStyle(.compact).labelsHidden().tint(themeC1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(themeC1.opacity(0.6)).padding(.top, 18)
                                    VStack(spacing: 6) {
                                        Text("Bis").font(.caption.weight(.semibold))
                                            .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
                                        DatePicker("", selection: $customTimeEnd, displayedComponents: .hourAndMinute)
                                            .datePickerStyle(.compact).labelsHidden().tint(themeC1)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        VStack(spacing: 10) {
                            Button { submit() } label: {
                                Text("Hinzufügen").font(.headline)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(
                                        title.trimmingCharacters(in: .whitespaces).isEmpty
                                            ? AnyShapeStyle(Color.secondary.opacity(0.3))
                                            : AnyShapeStyle(LinearGradient(colors: [themeC1, themeC2],
                                                                           startPoint: .leading, endPoint: .trailing))
                                    )
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

                            Button { onAufgabenUebersicht() } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "list.bullet").font(.system(size: 13))
                                    Text("Aufgabenübersicht").font(.subheadline)
                                }
                                .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingCustom)
            }
            .navigationTitle("Schnellaufgabe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { titleFocused = true }
        .sheet(isPresented: $showingSlotEditor) {
            SlotEditorSheet(themeC1: themeC1, themeC2: themeC2, slots: $slots)
                .onDisappear { saveQuickSlots(slots) }
        }
    }

    private func slotButton(slot: QuickSlot) -> some View {
        let isSelected = selectedSlotID == slot.id && !showingCustom
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                if isSelected { selectedSlotID = nil } else { selectedSlotID = slot.id; showingCustom = false }
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: slot.icon).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : themeC1)
                Text(slot.name).font(.system(size: 11, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    .foregroundStyle(isSelected ? .white : (isDark ? .white.opacity(0.8) : .primary))
                Text(String(format: "%02d:%02d", slot.hour, slot.minute))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(colors: [themeC1, themeC2], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.primary.opacity(0.07)),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
    }

    private var customSlotButton: some View {
        let isSelected = showingCustom
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                if isSelected { showingCustom = false } else { showingCustom = true; selectedSlotID = nil }
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: "clock.badge.plus").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : themeC1)
                Text("Eigene").font(.system(size: 11, weight: .semibold)).lineLimit(1)
                    .foregroundStyle(isSelected ? .white : (isDark ? .white.opacity(0.8) : .primary))
                Text(isSelected ? "\(f.string(from: customTimeStart))–\(f.string(from: customTimeEnd))" : "– : –")
                    .font(.system(size: 9, design: .monospaced)).minimumScaleFactor(0.7).lineLimit(1)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(colors: [themeC1, themeC2], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.primary.opacity(0.07)),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let endDate: Date? = showingCustom ? customTimeEnd : nil
        if let b = selectedBaustein { bausteinStore.verwendungErhoehen(b) }
        onAdd(trimmed, dueDate, endDate)
        dismiss()
    }

    private func bausteinAnwenden(_ b: TagesplanBaustein) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            title = b.titel
            selectedBaustein = b
            showingCustom = false
            selectedSlotID = nil
            if b.hatStartZeit {
                let cal = Calendar.current
                customTimeStart = cal.date(bySettingHour: b.startStunde,
                                           minute: b.startMinute, second: 0, of: Date()) ?? Date()
                if b.hatEndZeit {
                    customTimeEnd = cal.date(bySettingHour: b.endStunde,
                                             minute: b.endMinute, second: 0, of: Date()) ?? Date()
                    showingCustom = true
                }
            }
        }
        titleFocused = false
    }

    private var smartVorschlaegeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(themeC1)
                Text("Vorschläge")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isDark ? .white.opacity(0.45) : .secondary)
            }
            .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vorschlaege) { b in
                        let isSelected = selectedBaustein?.id == b.id
                        Button { bausteinAnwenden(b) } label: {
                            HStack(spacing: 7) {
                                ZStack {
                                    Circle()
                                        .fill(b.farbe.color.opacity(isSelected ? 0.35 : 0.15))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: b.symbol)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(b.farbe.color)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(b.titel)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)
                                        .lineLimit(1)
                                    Text(b.zeitLabel)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(b.farbe.color.opacity(0.85))
                                        .lineLimit(1)
                                }
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(b.farbe.color)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                isSelected
                                    ? AnyShapeStyle(b.farbe.color.opacity(isDark ? 0.25 : 0.13))
                                    : AnyShapeStyle(Color.primary.opacity(0.06)),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected ? b.farbe.color.opacity(0.5) : Color.clear, lineWidth: 1.2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Slot Editor Sheet

struct SlotEditorSheet: View {
    let themeC1: Color
    let themeC2: Color
    @Binding var slots: [QuickSlot]
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var editingSlot: QuickSlot? = nil

    var isDark: Bool { colorScheme == .dark }

    var body: some View {
        NavigationStack {
            List {
                ForEach($slots) { $slot in
                    Button { editingSlot = slot } label: {
                        HStack(spacing: 14) {
                            Image(systemName: slot.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(themeC1)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slot.name).font(.body.weight(.medium))
                                Text(String(format: "%02d:%02d Uhr", slot.hour, slot.minute))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12)).foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { slots.remove(atOffsets: $0) }
                .onMove { slots.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    let newSlot = QuickSlot(name: "Neu", icon: "clock", hour: 9)
                    slots.append(newSlot)
                    editingSlot = newSlot
                } label: {
                    Label("Zeitraum hinzufügen", systemImage: "plus.circle.fill")
                        .foregroundStyle(themeC1)
                }
            }
            .navigationTitle("Zeiträume bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { saveQuickSlots(slots); dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
        }
        .sheet(item: $editingSlot) { slot in
            SingleSlotEditor(themeC1: themeC1, themeC2: themeC2, slot: slot) { updated in
                if let i = slots.firstIndex(where: { $0.id == updated.id }) {
                    slots[i] = updated
                }
            }
        }
    }
}

// MARK: - Single Slot Editor

private let slotIcons: [String] = [
    "sun.and.horizon.fill", "sun.max", "sun.max.fill", "sun.haze.fill",
    "cloud.sun.fill", "cloud.fill", "moon.fill", "moon.stars.fill",
    "star.fill", "clock", "clock.badge.plus", "clock.badge.checkmark",
    "alarm.fill", "bed.double.fill", "cup.and.saucer.fill", "fork.knife",
    "figure.walk", "figure.run", "dumbbell.fill", "brain.head.profile",
    "book.fill", "laptopcomputer", "house.fill", "car.fill",
]

struct SingleSlotEditor: View {
    let themeC1: Color
    let themeC2: Color
    let slot: QuickSlot
    let onSave: (QuickSlot) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var name: String
    @State private var icon: String
    @State private var timeDate: Date

    var isDark: Bool { colorScheme == .dark }

    init(themeC1: Color, themeC2: Color, slot: QuickSlot, onSave: @escaping (QuickSlot) -> Void) {
        self.themeC1 = themeC1; self.themeC2 = themeC2; self.slot = slot; self.onSave = onSave
        _name = State(initialValue: slot.name)
        _icon = State(initialValue: slot.icon)
        let cal = Calendar.current
        _timeDate = State(initialValue:
            cal.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: Date()) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    HStack(spacing: 12) {
                        Image(systemName: icon).foregroundStyle(themeC1).frame(width: 24)
                        TextField("Name", text: $name)
                    }
                }

                Section("Uhrzeit") {
                    DatePicker("Zeit", selection: $timeDate, displayedComponents: .hourAndMinute)
                        .tint(themeC1)
                }

                Section("Symbol") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(slotIcons, id: \.self) { sym in
                            Button {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { icon = sym }
                            } label: {
                                Image(systemName: sym)
                                    .font(.system(size: 20))
                                    .foregroundStyle(icon == sym ? .white : themeC1)
                                    .frame(width: 42, height: 42)
                                    .background(
                                        icon == sym
                                            ? AnyShapeStyle(LinearGradient(colors: [themeC1, themeC2],
                                                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                                            : AnyShapeStyle(themeC1.opacity(0.1)),
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Zeitraum bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        let cal = Calendar.current
                        let h = cal.component(.hour, from: timeDate)
                        let m = cal.component(.minute, from: timeDate)
                        var updated = slot
                        updated.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? slot.name : name
                        updated.icon = icon
                        updated.hour = h
                        updated.minute = m
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Einplanen Sheet

// MARK: - Aufgaben Übersicht Sheet

struct AufgabenUebersichtSheet: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("filterCurrentMonthOnly") private var filterCurrentMonthOnly = false

    let themeC1: Color
    let themeC2: Color
    let onSelect: (TodoItem) -> Void

    @State private var collapsedGroups: Set<String> = []
    @State private var searchText: String = ""

    var isDark: Bool { colorScheme == .dark }

    private let groups: [(id: String, title: String, icon: String, color: Color, kind: GroupKind)] = [
        ("today",   "Heute",         "sun.max.fill",               .orange, .today),
        ("overdue", "Überfällig",    "exclamationmark.triangle.fill", .red,  .overdue),
        ("week",    "Diese Woche",   "calendar.badge.clock",       .blue,   .thisWeek),
        ("later",   "Später",        "arrow.right.circle.fill",    .secondary, .later),
        ("nodate",  "Ohne Datum",    "tray.fill",                  .secondary, .noDate),
    ]

    enum GroupKind { case today, overdue, thisWeek, later, noDate }

    private var baseTodos: [TodoItem] {
        let all = todoStore.todos.filter { !$0.isCompleted }
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty { return all }
        let q = searchText.lowercased()
        return all.filter { $0.title.lowercased().contains(q) }
    }

    private func todos(for kind: GroupKind) -> [TodoItem] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekEnd = cal.date(byAdding: .day, value: 7, to: today) ?? today
        return baseTodos.filter { todo in
            switch kind {
            case .today:   return todo.dueDate.map { cal.isDateInToday($0) } == true
            case .overdue: return todo.dueDate.map { $0 < today } == true
            case .thisWeek:
                guard let d = todo.dueDate else { return false }
                return d > today && d <= weekEnd && !cal.isDateInToday(d)
            case .later:   return todo.dueDate.map { $0 > weekEnd } == true
            case .noDate:  return todo.dueDate == nil
            }
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView()

                VStack(spacing: 0) {
                    // Search
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Aufgabe suchen…", text: $searchText)
                            .font(.system(size: 16))
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(groups, id: \.id) { group in
                                let items = todos(for: group.kind)
                                if !items.isEmpty {
                                    groupSection(group: group, items: items)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Aufgaben einplanen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    private func groupSection(group: (id: String, title: String, icon: String, color: Color, kind: GroupKind), items: [TodoItem]) -> some View {
        let collapsed = collapsedGroups.contains(group.id)
        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if collapsed { collapsedGroups.remove(group.id) }
                    else { collapsedGroups.insert(group.id) }
                }
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2).fill(group.color).frame(width: 3, height: 24)
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(group.color.opacity(0.15)).frame(width: 30, height: 30)
                        Image(systemName: group.icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(group.color)
                    }
                    Text(group.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(isDark ? .white : .primary)
                    Spacer()
                    Text("\(items.count)").font(.caption.weight(.bold)).foregroundStyle(group.color)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(group.color.opacity(0.12), in: Capsule())
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        .rotationEffect(.degrees(collapsed ? 0 : 90))
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
            }
            .buttonStyle(.plain)

            if !collapsed {
                Divider().opacity(0.15).padding(.horizontal, 14)
                VStack(spacing: 0) {
                    ForEach(items) { todo in
                        Button {
                            onSelect(todo)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.badge.plus")
                                    .font(.system(size: 16))
                                    .foregroundStyle(group.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(todo.title).font(.subheadline.weight(.medium))
                                        .foregroundStyle(isDark ? .white.opacity(0.9) : .primary).lineLimit(1)
                                    if let due = todo.dueDate {
                                        Text(due, style: .date).font(.caption2).foregroundStyle(group.color.opacity(0.7))
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if todo.id != items.last?.id { Divider().opacity(0.1).padding(.leading, 46) }
                    }
                }
            }
        }
        .themeGlass(cornerRadius: 16)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: collapsed)
    }
}

// MARK: - Einplanen Sheet

struct EinplanenSheet: View {
    let todo: TodoItem
    let onSave: (TodoItem) -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirm = false
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @State private var editedTitle: String
    @State private var selectedDate: Date
    @State private var selectedEndDate: Date
    @State private var appeared = false

    var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    init(todo: TodoItem, onSave: @escaping (TodoItem) -> Void, onDelete: (() -> Void)? = nil) {
        self.todo = todo
        self.onSave = onSave
        self.onDelete = onDelete
        _editedTitle = State(initialValue: todo.title)
        let cal = Calendar.current
        let base = todo.dueDate ?? Date()
        let dateBase = cal.startOfDay(for: base)
        let h = cal.component(.hour, from: base)
        let m = cal.component(.minute, from: base)
        let start = cal.date(bySettingHour: max(h, 0), minute: m, second: 0, of: dateBase) ?? base
        _selectedDate = State(initialValue: start)
        if let existingEnd = todo.endDate {
            let eh = cal.component(.hour, from: existingEnd)
            let em = cal.component(.minute, from: existingEnd)
            _selectedEndDate = State(initialValue:
                cal.date(bySettingHour: eh, minute: em, second: 0, of: dateBase) ?? start.addingTimeInterval(3600))
        } else {
            _selectedEndDate = State(initialValue: start.addingTimeInterval(3600))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // Task title — editable
                        HStack(spacing: 12) {
                            Image(systemName: "pencil.line")
                                .font(.system(size: 20))
                                .foregroundStyle(themeC1)
                            TextField("Aufgabenname", text: $editedTitle)
                                .font(.headline)
                                .foregroundStyle(isDark ? .white : .primary)
                                .submitLabel(.done)
                        }
                        .padding(14)
                        .themeGlass(cornerRadius: 14)

                        // Datum
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Datum", systemImage: "calendar")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isDark ? .white.opacity(0.6) : .secondary)
                            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                                .tint(themeC1)
                        }
                        .padding(16)
                        .themeGlass(cornerRadius: 16)

                        // Von / Bis — frei wählbar
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Uhrzeit", systemImage: "clock")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isDark ? .white.opacity(0.6) : .secondary)

                            HStack(spacing: 0) {
                                // Von
                                VStack(spacing: 6) {
                                    Text("Von")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
                                    DatePicker("", selection: $selectedDate,
                                               displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .tint(themeC1)
                                        .onChange(of: selectedDate) { newStart in
                                            if selectedEndDate <= newStart {
                                                selectedEndDate = newStart.addingTimeInterval(3600)
                                            }
                                        }
                                }
                                .frame(maxWidth: .infinity)

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(themeC1.opacity(0.5))
                                    .padding(.horizontal, 8)

                                // Bis
                                VStack(spacing: 6) {
                                    Text("Bis")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
                                    DatePicker("", selection: $selectedEndDate,
                                               in: selectedDate...,
                                               displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .tint(themeC1)
                                }
                                .frame(maxWidth: .infinity)
                            }

                            // Dauer-Badge
                            let mins = Int(selectedEndDate.timeIntervalSince(selectedDate) / 60)
                            let durLabel: String = {
                                guard mins > 0 else { return " " }
                                if mins >= 60 {
                                    return mins % 60 == 0 ? "\(mins/60)h" : "\(mins/60)h \(mins%60)min"
                                }
                                return "\(mins)min"
                            }()
                            HStack {
                                Spacer()
                                Text(durLabel)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(themeC1)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(mins > 0 ? themeC1.opacity(0.12) : Color.clear,
                                                in: Capsule())
                                    .animation(nil, value: durLabel)
                                Spacer()
                            }
                        }
                        .padding(16)
                        .themeGlass(cornerRadius: 16)

                        // Save button
                        Button {
                            var updated = todo
                            let trimmed = editedTitle.trimmingCharacters(in: .whitespaces)
                            updated.title = trimmed.isEmpty ? todo.title : trimmed
                            updated.dueDate = selectedDate
                            updated.endDate = selectedEndDate > selectedDate ? selectedEndDate : nil
                            onSave(updated)
                            dismiss()
                        } label: {
                            Text("Einplanen")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(LinearGradient(colors: [themeC1, themeC2],
                                                           startPoint: .leading, endPoint: .trailing))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        if onDelete != nil {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("Aufgabe löschen", systemImage: "trash")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.red.opacity(isDark ? 0.18 : 0.10),
                                                in: RoundedRectangle(cornerRadius: 14))
                                    .foregroundStyle(Color.red)
                                    .overlay(RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.red.opacity(0.25), lineWidth: 1))
                            }
                            .confirmationDialog("Aufgabe löschen?",
                                               isPresented: $showDeleteConfirm,
                                               titleVisibility: .visible) {
                                Button("Löschen", role: .destructive) {
                                    onDelete?()
                                    dismiss()
                                }
                                Button("Abbrechen", role: .cancel) {}
                            } message: {
                                Text("\"\(todo.title)\" wird unwiderruflich gelöscht.")
                            }
                        }
                    }
                    .padding(20)
                }
                .transaction { $0.animation = appeared ? $0.animation : nil }
                .onAppear { appeared = true }
            }
            .navigationTitle("Einplanen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Export Views (for PDF rendering)

private struct ExportSectionView: View {
    let label: String
    let icon: String
    let color: Color
    let tasks: [TodoItem]
    let themeC1: Color

    private let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                Rectangle().fill(color.opacity(0.2)).frame(height: 1)
            }
            .padding(.bottom, 8)

            if tasks.isEmpty {
                Text("Keine Aufgaben")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .padding(.bottom, 8)
            } else {
                ForEach(tasks) { task in
                    HStack(alignment: .top, spacing: 10) {
                        // Time column
                        VStack(alignment: .trailing, spacing: 2) {
                            if let due = task.dueDate {
                                Text(timeFmt.string(from: due))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(themeC1)
                            }
                            if let end = task.endDate {
                                Text(timeFmt.string(from: end))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 40, alignment: .trailing)

                        // Bullet
                        Circle()
                            .fill(themeC1.opacity(task.isCompleted ? 0.3 : 0.8))
                            .frame(width: 7, height: 7)
                            .padding(.top, 3)

                        // Title + duration
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                .strikethrough(task.isCompleted)
                            if let due = task.dueDate, let end = task.endDate, end > due {
                                let mins = Int(end.timeIntervalSince(due) / 60)
                                let dur = mins >= 60
                                    ? (mins % 60 == 0 ? "\(mins/60)h" : "\(mins/60)h \(mins%60)min")
                                    : "\(mins)min"
                                Text(dur)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 5)

                    if task.id != tasks.last?.id {
                        Divider().opacity(0.2).padding(.leading, 50)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(white: 0.97), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

struct TagesplanExportView: View {
    let date: Date
    let todos: [TodoItem]
    let themeC1: Color
    let themeC2: Color

    private var cal: Calendar { Calendar.current }

    private func tasks(for hours: Range<Int>) -> [TodoItem] {
        todos.filter { t in
            guard let due = t.dueDate else { return false }
            guard cal.isDate(due, inSameDayAs: date) else { return false }
            return hours.contains(cal.component(.hour, from: due))
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, d. MMMM yyyy"
        return f.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tagesplan")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(themeC1)
                    Text(dateString)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(LinearGradient(colors: [themeC1, themeC2],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .padding(.bottom, 4)

            Divider()

            ExportSectionView(label: "Morgen",  icon: "sun.and.horizon.fill", color: .orange,
                              tasks: tasks(for: 6..<12), themeC1: themeC1)
            ExportSectionView(label: "Mittag",  icon: "sun.max.fill",         color: themeC1,
                              tasks: tasks(for: 12..<18), themeC1: themeC1)
            ExportSectionView(label: "Abend",   icon: "moon.stars.fill",      color: .indigo,
                              tasks: tasks(for: 18..<24), themeC1: themeC1)

            Spacer(minLength: 12)

            // Footer
            HStack {
                Spacer()
                Text("Erstellt mit BeeFocus")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(Color.white)
    }
}

struct TagesplanWocheExportView: View {
    let days: [Date]
    let todos: [TodoItem]
    let themeC1: Color
    let themeC2: Color
    let kw: Int

    private var cal: Calendar { Calendar.current }

    private func tasks(for day: Date) -> [TodoItem] {
        todos.filter { t in
            guard let due = t.dueDate else { return false }
            return cal.isDate(due, inSameDayAs: day)
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEE d. MMM"
        return f
    }()

    private let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wochenplan")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(themeC1)
                    Text("KW \(kw)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(LinearGradient(colors: [themeC1, themeC2],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .padding(.bottom, 4)

            Divider()

            ForEach(days, id: \.self) { day in
                let dayTasks = tasks(for: day)
                let isToday = cal.isDateInToday(day)

                VStack(alignment: .leading, spacing: 6) {
                    // Day header
                    HStack(spacing: 8) {
                        Text(dayFmt.string(from: day).capitalized)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isToday ? themeC1 : .primary)
                        if isToday {
                            Text("Heute")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(themeC1, in: Capsule())
                        }
                        Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1)
                    }

                    if dayTasks.isEmpty {
                        Text("Keine Aufgaben")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    } else {
                        ForEach(dayTasks) { task in
                            HStack(alignment: .top, spacing: 8) {
                                if let due = task.dueDate {
                                    Text(timeFmt.string(from: due))
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(themeC1)
                                        .frame(width: 36, alignment: .trailing)
                                } else {
                                    Spacer().frame(width: 36)
                                }
                                Circle()
                                    .fill(themeC1.opacity(0.7))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 3)
                                Text(task.title)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                                if let due = task.dueDate, let end = task.endDate, end > due {
                                    let mins = Int(end.timeIntervalSince(due) / 60)
                                    let dur = mins >= 60 ? "\(mins/60)h" : "\(mins)min"
                                    Text(dur).font(.system(size: 9)).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color(white: 0.97), in: RoundedRectangle(cornerRadius: 8))
            }

            Spacer(minLength: 12)

            HStack {
                Spacer()
                Text("Erstellt mit BeeFocus")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(Color.white)
    }
}

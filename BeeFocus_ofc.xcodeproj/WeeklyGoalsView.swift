import SwiftUI
import Combine

fileprivate struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var velocity: CGSize
    var rotation: Angle
    var spin: Double
}

fileprivate struct ConfettiView: View {
    @Binding var isActive: Bool
    @State private var particles: [ConfettiParticle] = []
    @State private var timerCancellable: AnyCancellable?

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Rectangle()
                    .fill(p.color)
                    .frame(width: p.size * 0.6, height: p.size)
                    .rotationEffect(p.rotation)
                    .position(x: p.x, y: p.y)
                    .opacity(isActive ? 1 : 0)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { active in
            if active { start() } else { stop() }
        }
    }

    private func start() {
        particles = generate()
        timerCancellable?.cancel()
        // Simple animation loop ~2 seconds
        let startDate = Date()
        timerCancellable = Timer.publish(every: 1.0/60.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let t = Date().timeIntervalSince(startDate)
                if t > 2.0 {
                    withAnimation(.easeOut(duration: 0.4)) { isActive = false }
                    stop()
                    return
                }
                withAnimation(.linear(duration: 1.0/60.0)) {
                    for i in particles.indices {
                        particles[i].y += particles[i].velocity.height
                        particles[i].x += particles[i].velocity.width * 0.2
                        particles[i].rotation += .degrees(particles[i].spin)
                        // Gravity
                        particles[i].velocity.height += 0.35
                    }
                }
            }
    }

    private func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func generate() -> [ConfettiParticle] {
        let colors: [Color] = [.red, .orange, .yellow, .green, .mint, .blue, .purple, .pink]
        let width = UIScreen.main.bounds.width
        return (0..<40).map { _ in
            let x = CGFloat.random(in: 20...(width - 20))
            let y: CGFloat = -20
            let size = CGFloat.random(in: 8...18)
            let color = colors.randomElement() ?? .blue
            let vx = CGFloat.random(in: -2...2)
            let vy = CGFloat.random(in: -1...1)
            let rot = Angle.degrees(Double.random(in: 0...360))
            let spin = Double.random(in: -6...6)
            return ConfettiParticle(x: x, y: y, size: size, color: color, velocity: CGSize(width: vx, height: vy), rotation: rot, spin: spin)
        }
    }
}

struct WeeklyGoal: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool
}

private struct WeeklyGoalsStore {
    private static let storageKeyPrefix = "weekly_goals_" // + year-week string

    static func yearWeek(for date: Date = Date()) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = comps.yearForWeekOfYear ?? 1970
        let week = comps.weekOfYear ?? 1
        return String(format: "%04d-W%02d", year, week)
    }

    static func load(for yearWeek: String = yearWeek()) -> [WeeklyGoal] {
        let key = storageKeyPrefix + yearWeek
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        if let decoded = try? JSONDecoder().decode([WeeklyGoal].self, from: data) {
            return decoded
        }
        return []
    }

    static func save(_ goals: [WeeklyGoal], for yearWeek: String = yearWeek()) {
        let key = storageKeyPrefix + yearWeek
        if let data = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct WeeklyGoalsView: View {
    @State private var goals: [WeeklyGoal] = []
    @State private var newGoalTitle: String = ""
    @State private var currentYearWeek: String = WeeklyGoalsStore.yearWeek()
    @State private var showConfetti: Bool = false

    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 16) {
                    HStack {
                        TextField(localizer.localizedString(forKey: "add_weekly_goal_placeholder"), text: $newGoalTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit(addGoal)
                        Button(action: addGoal) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .disabled(newGoalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        let total = max(goals.count, 1)
                        let completed = goals.filter { $0.isCompleted }.count
                        let progress = Double(completed) / Double(total)
                        let reached = progress >= 1.0 && goals.count > 0
                        DispatchQueue.main.async { if reached && !showConfetti { showConfetti = true } }
                        let color: Color = progress >= 1.0 ? .green : (progress >= 0.66 ? .yellow : (progress >= 0.33 ? .orange : .red))
                        HStack {
                            Text(localizer.localizedString(forKey: "progress"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(completed)/\(goals.count) (\(Int(progress * 100))%)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(.secondary)
                            if progress >= 1.0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "trophy.fill")
                                        .foregroundColor(.yellow)
                                    Text(localizer.localizedString(forKey: "weekly_goal_completed_badge"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        ProgressView(value: progress)
                            .tint(color)
                            .animation(.easeInOut(duration: 0.25), value: progress)
                    }
                    .padding(.horizontal)

                    if goals.isEmpty {
                        Text(localizer.localizedString(forKey: "no_weekly_goals"))
                            .foregroundColor(.secondary)
                            .padding(.top, 20)
                    } else {
                        List {
                            ForEach(goals) { goal in
                                HStack {
                                    Button(action: { toggle(goal) }) {
                                        Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(goal.isCompleted ? .green : .gray)
                                    }
                                    .buttonStyle(.plain)
                                    Text(goal.title)
                                        .strikethrough(goal.isCompleted)
                                        .foregroundColor(goal.isCompleted ? .secondary : .primary)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { toggle(goal) }
                            }
                            .onDelete(perform: delete)
                        }
                        .listStyle(.insetGrouped)
                    }

                    Spacer(minLength: 8)

                    HStack {
                        Text(weekTitle())
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(localizer.localizedString(forKey: "go_to_current_week")) {
                            switchToCurrentWeek()
                        }
                    }
                    .padding(.horizontal)
                }
                ConfettiView(isActive: $showConfetti)
                    .ignoresSafeArea()
            }
            .navigationTitle(localizer.localizedString(forKey: "weekly_goals_title"))
            .onAppear { loadWeek(WeeklyGoalsStore.yearWeek()) }
        }
    }

    private func weekTitle() -> String {
        return localizer.localizedString(forKey: "week") + ": " + currentYearWeek
    }

    private func addGoal() {
        let title = newGoalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        goals.append(WeeklyGoal(id: UUID(), title: title, isCompleted: false))
        newGoalTitle = ""
        WeeklyGoalsStore.save(goals, for: currentYearWeek)
    }

    private func toggle(_ goal: WeeklyGoal) {
        if let idx = goals.firstIndex(of: goal) {
            goals[idx].isCompleted.toggle()
            WeeklyGoalsStore.save(goals, for: currentYearWeek)
        }
    }

    private func delete(at offsets: IndexSet) {
        goals.remove(atOffsets: offsets)
        WeeklyGoalsStore.save(goals, for: currentYearWeek)
    }

    private func loadWeek(_ yearWeek: String) {
        currentYearWeek = yearWeek
        goals = WeeklyGoalsStore.load(for: yearWeek)
    }

    private func switchToCurrentWeek() {
        let yw = WeeklyGoalsStore.yearWeek()
        if yw != currentYearWeek {
            // Reset goals for new week (empty)
            loadWeek(yw)
        }
    }
}


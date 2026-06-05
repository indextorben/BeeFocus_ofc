import Foundation
import UIKit
import Combine

// Tracks time spent inside the BeeFocus app per day.
// Device-wide screen time is not accessible to third-party apps.
final class ScreenTimeTracker: ObservableObject {

    static let shared = ScreenTimeTracker()

    private let storageKey = "beefocus_app_usage_seconds"
    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // Committed seconds for today (saved to UserDefaults)
    @Published private(set) var todaySeconds: Int = 0
    // Live seconds since this foreground session started
    @Published private(set) var liveSessionSeconds: Int = 0

    var totalTodaySeconds: Int { todaySeconds + liveSessionSeconds }

    private var usageData: [String: Int] = [:]
    private var sessionStart: Date? = nil
    private var liveTimer: AnyCancellable?

    private init() {
        loadData()
        todaySeconds = usageData[key(for: Date())] ?? 0
        startSession()
        observeAppLifecycle()
    }

    // MARK: - Lifecycle

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        startSession()
    }

    @objc private func appWillResignActive() {
        commitSession()
    }

    // MARK: - Session handling

    private func startSession() {
        sessionStart = Date()
        liveSessionSeconds = 0
        // Tick every second for live counter
        liveTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.sessionStart else { return }
                self.liveSessionSeconds = Int(Date().timeIntervalSince(start))
            }
    }

    private func commitSession() {
        liveTimer?.cancel()
        liveTimer = nil
        guard let start = sessionStart else { return }
        let elapsed = max(0, Int(Date().timeIntervalSince(start)))
        guard elapsed > 0 else { return }
        let k = key(for: Date())
        usageData[k] = (usageData[k] ?? 0) + elapsed
        todaySeconds = usageData[k] ?? 0
        liveSessionSeconds = 0
        sessionStart = nil
        saveData()
    }

    // MARK: - Data access

    func seconds(for date: Date) -> Int {
        // For today, include live session
        if Calendar.current.isDateInToday(date) { return totalTodaySeconds }
        return usageData[key(for: date)] ?? 0
    }

    var last7Days: [(date: Date, seconds: Int)] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) ?? Date()
            return (date, seconds(for: date))
        }
    }

    var weeklyAverageSeconds: Int {
        let days = last7Days
        let activeDays = days.filter { $0.seconds > 0 }
        guard !activeDays.isEmpty else { return 0 }
        return activeDays.map(\.seconds).reduce(0, +) / activeDays.count
    }

    // MARK: - Helpers

    private func key(for date: Date) -> String { df.string(from: date) }

    private func loadData() {
        usageData = (UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Int]) ?? [:]
    }

    private func saveData() {
        UserDefaults.standard.set(usageData, forKey: storageKey)
    }

    static func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0 Min." }
        if seconds < 60 { return "\(seconds) Sek." }
        let m = seconds / 60
        if m < 60 { return "\(m) Min." }
        let h = m / 60
        let rem = m % 60
        return rem == 0 ? "\(h) Std." : "\(h) Std. \(rem) Min."
    }
}

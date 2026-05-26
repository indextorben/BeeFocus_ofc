import Foundation
import FamilyControls
import ManagedSettings

@available(iOS 16, *)
@MainActor
class FokusModeManager: ObservableObject {
    static let shared = FokusModeManager()

    @Published var isAuthorized = false
    @Published var isFocusModeActive = false
    @Published var selection = FamilyActivitySelection()
    @Published var blockedDomains: [String] = []
    @Published var dailyFocusSeconds: [String: Int] = [:]
    @Published var unlockedAchievementIDs: Set<String> = []

    private let store = ManagedSettingsStore()
    private let iCloud = NSUbiquitousKeyValueStore.default
    private var focusStartTime: Date?

    private init() {
        // Lokale Daten laden
        isFocusModeActive = UserDefaults.standard.bool(forKey: "focusModeActive")
        if let data = UserDefaults.standard.data(forKey: "focusModeSelection"),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = decoded
        }
        blockedDomains = UserDefaults.standard.stringArray(forKey: "focusModeBlockedDomains") ?? []
        if let stored = UserDefaults.standard.dictionary(forKey: "focusDailySeconds") as? [String: Int] {
            dailyFocusSeconds = stored
        }
        if let saved = UserDefaults.standard.stringArray(forKey: "unlockedAchievements") {
            unlockedAchievementIDs = Set(saved)
        }
        let storedGoal = UserDefaults.standard.integer(forKey: "focusDailyGoalMinutes")
        dailyGoalMinutes = storedGoal > 0 ? storedGoal : 120
        if isFocusModeActive,
           let ts = UserDefaults.standard.object(forKey: "focusStartTime") as? Double {
            focusStartTime = Date(timeIntervalSince1970: ts)
        }
        checkAuthorizationStatus()

        // iCloud: synchronisieren und mit lokalen Daten zusammenführen
        // Beim ersten Start nach Neuinstallation (leere UserDefaults) werden alle
        // Einstellungen aus iCloud wiederhergestellt.
        iCloud.synchronize()
        mergeFromiCloud()

        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloud,
            queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.mergeFromiCloud() }
        }
    }

    private func mergeFromiCloud() {
        // Fokus-Statistik: nimm jeweils den höheren Wert pro Tag
        if let remote = iCloud.dictionary(forKey: "focusDailySeconds") as? [String: Int] {
            var changed = false
            for (key, value) in remote {
                let current = dailyFocusSeconds[key, default: 0]
                if value > current { dailyFocusSeconds[key] = value; changed = true }
            }
            if changed { UserDefaults.standard.set(dailyFocusSeconds, forKey: "focusDailySeconds") }
        }

        // Freigeschaltete Achievements: Vereinigung beider Geräte
        if let remote = iCloud.array(forKey: "unlockedAchievements") as? [String] {
            let merged = unlockedAchievementIDs.union(Set(remote))
            if merged != unlockedAchievementIDs {
                unlockedAchievementIDs = merged
                UserDefaults.standard.set(Array(merged), forKey: "unlockedAchievements")
            }
        }

        // Gesperrte Domains: Vereinigung beider Geräte
        if let remote = iCloud.array(forKey: "focusModeBlockedDomains") as? [String] {
            let merged = Array(Set(blockedDomains).union(Set(remote))).sorted()
            if merged != blockedDomains.sorted() {
                blockedDomains = merged
                UserDefaults.standard.set(blockedDomains, forKey: "focusModeBlockedDomains")
            }
        }

        // App-Auswahl: Vereinigung der Token beider Geräte
        if let remoteData = iCloud.data(forKey: "focusModeSelection"),
           let remote = try? JSONDecoder().decode(FamilyActivitySelection.self, from: remoteData) {
            let mergedApps = selection.applicationTokens.union(remote.applicationTokens)
            let mergedCats = selection.categoryTokens.union(remote.categoryTokens)
            let mergedWeb  = selection.webDomainTokens.union(remote.webDomainTokens)
            if mergedApps != selection.applicationTokens ||
               mergedCats != selection.categoryTokens ||
               mergedWeb  != selection.webDomainTokens {
                selection.applicationTokens = mergedApps
                selection.categoryTokens    = mergedCats
                selection.webDomainTokens   = mergedWeb
                if let data = try? JSONEncoder().encode(selection) {
                    UserDefaults.standard.set(data, forKey: "focusModeSelection")
                }
            }
        }
    }

    // MARK: - Computed Stats

    var selectedAppCount: Int { selection.applicationTokens.count }
    var selectedCategoryCount: Int { selection.categoryTokens.count }
    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !blockedDomains.isEmpty
    }

    var todaySeconds: Int { dailyFocusSeconds[dateKey(for: Date()), default: 0] }

    var weekSeconds: Int {
        let cal = Calendar.current
        return (0..<7).compactMap { offset -> Int? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return dailyFocusSeconds[dateKey(for: day)]
        }.reduce(0, +)
    }

    var last7Days: [(date: Date, seconds: Int)] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap { offset -> (Date, Int)? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return (day, dailyFocusSeconds[dateKey(for: day), default: 0])
        }
    }

    var currentSessionStart: Date? { focusStartTime }

    // MARK: - Goal & Streak

    @Published var dailyGoalMinutes: Int = 120

    func setGoalMinutes(_ minutes: Int) {
        dailyGoalMinutes = minutes
        UserDefaults.standard.set(minutes, forKey: "focusDailyGoalMinutes")
        iCloud.set(minutes, forKey: "focusDailyGoalMinutes")
        iCloud.synchronize()
    }

    var todayProgress: Double {
        guard dailyGoalMinutes > 0 else { return 0 }
        var total = todaySeconds
        if isFocusModeActive, let start = focusStartTime {
            total += Int(Date().timeIntervalSince(start))
        }
        return min(1.0, Double(total) / Double(dailyGoalMinutes * 60))
    }

    var currentStreak: Int {
        let minSecs = 1800
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        var todayTotal = todaySeconds
        if isFocusModeActive, let start = focusStartTime {
            todayTotal += Int(Date().timeIntervalSince(start))
        }
        if todayTotal < minSecs {
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var streak = 0
        for _ in 0..<365 {
            if (dailyFocusSeconds[dateKey(for: day)] ?? 0) >= minSecs {
                streak += 1
                day = cal.date(byAdding: .day, value: -1, to: day) ?? day
            } else { break }
        }
        return streak
    }

    var longestStreak: Int {
        let minSecs = 1800
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current
        let sorted = dailyFocusSeconds.keys.sorted().compactMap { k -> (Date, Int)? in
            guard let d = fmt.date(from: k) else { return nil }
            return (d, dailyFocusSeconds[k] ?? 0)
        }
        var best = 0, cur = 0
        var prev: Date? = nil
        for (date, secs) in sorted {
            if secs >= minSecs {
                if let p = prev, cal.dateComponents([.day], from: p, to: date).day == 1 { cur += 1 }
                else { cur = 1 }
                best = max(best, cur); prev = date
            } else { cur = 0; prev = nil }
        }
        return best
    }

    // MARK: - Authorization

    func requestAuthorizationIfNeeded() async {
        guard !isAuthorized else { return }
        await requestAuthorization()
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    func checkAuthorizationStatus() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    // MARK: - Domains

    func addDomain(_ raw: String) {
        let cleaned = cleanDomain(raw)
        guard !cleaned.isEmpty, !blockedDomains.contains(cleaned) else { return }
        blockedDomains.append(cleaned)
        saveDomains()
        if isFocusModeActive { enableFocusMode() }
    }

    func removeDomain(_ domain: String) {
        blockedDomains.removeAll { $0 == domain }
        saveDomains()
        if isFocusModeActive { enableFocusMode() }
    }

    // MARK: - Focus Mode

    func enableFocusMode() {
        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        if !blockedDomains.isEmpty {
            let webDomains = Set(blockedDomains.compactMap { WebDomain(domain: $0) })
            store.webContent.blockedByFilter = .specific(webDomains)
        }
        if focusStartTime == nil {
            focusStartTime = Date()
            UserDefaults.standard.set(focusStartTime!.timeIntervalSince1970, forKey: "focusStartTime")
        }
        isFocusModeActive = true
        UserDefaults.standard.set(true, forKey: "focusModeActive")
    }

    func disableFocusMode() {
        commitCurrentSession()
        store.clearAllSettings()
        isFocusModeActive = false
        focusStartTime = nil
        UserDefaults.standard.set(false, forKey: "focusModeActive")
        UserDefaults.standard.removeObject(forKey: "focusStartTime")
    }

    func commitCurrentSession() {
        guard let start = focusStartTime else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        guard elapsed > 0 else { return }
        let key = dateKey(for: start)
        dailyFocusSeconds[key, default: 0] += elapsed
        focusStartTime = Date()
        UserDefaults.standard.set(focusStartTime!.timeIntervalSince1970, forKey: "focusStartTime")
        saveDailySeconds()
    }

    // MARK: - Persistence

    func saveSelection() {
        if let data = try? JSONEncoder().encode(selection) {
            UserDefaults.standard.set(data, forKey: "focusModeSelection")
            iCloud.set(data, forKey: "focusModeSelection")
            iCloud.synchronize()
        }
    }

    private func saveDomains() {
        UserDefaults.standard.set(blockedDomains, forKey: "focusModeBlockedDomains")
        iCloud.set(blockedDomains, forKey: "focusModeBlockedDomains")
        iCloud.synchronize()
    }

    private func saveDailySeconds() {
        UserDefaults.standard.set(dailyFocusSeconds, forKey: "focusDailySeconds")
        iCloud.set(dailyFocusSeconds, forKey: "focusDailySeconds")
        iCloud.synchronize()
    }

    // MARK: - Achievements

    var maxTagesSekunden: Int {
        dailyFocusSeconds.values.max() ?? 0
    }

    var totalFokustage: Int {
        dailyFocusSeconds.values.filter { $0 > 0 }.count
    }

    var weekendFokus: Bool {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return dailyFocusSeconds.keys.contains { key in
            guard let date = fmt.date(from: key),
                  (dailyFocusSeconds[key] ?? 0) > 0 else { return false }
            let weekday = cal.component(.weekday, from: date)
            return weekday == 1 || weekday == 7
        }
    }

    func goalReachedCount(goalMinutes: Int) -> Int {
        guard goalMinutes > 0 else { return 0 }
        return dailyFocusSeconds.values.filter { $0 >= goalMinutes * 60 }.count
    }

    @discardableResult
    func checkAchievements(context: AchievementContext) -> [FokusAchievement] {
        var newlyUnlocked: [FokusAchievement] = []
        for achievement in FokusAchievement.all {
            guard !unlockedAchievementIDs.contains(achievement.id) else { continue }
            if achievement.isUnlocked(context) {
                unlockedAchievementIDs.insert(achievement.id)
                newlyUnlocked.append(achievement)
            }
        }
        if !newlyUnlocked.isEmpty {
            let arr = Array(unlockedAchievementIDs)
            UserDefaults.standard.set(arr, forKey: "unlockedAchievements")
            iCloud.set(arr, forKey: "unlockedAchievements")
            iCloud.synchronize()
        }
        return newlyUnlocked
    }

    var achievementBonusPunkte: Int {
        FokusAchievement.all
            .filter { unlockedAchievementIDs.contains($0.id) }
            .reduce(0) { $0 + $1.bonusPunkte }
    }

    // MARK: - Helpers

    func dateKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func cleanDomain(_ input: String) -> String {
        var s = input.lowercased().trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("https://") { s = String(s.dropFirst(8)) }
        if s.hasPrefix("http://") { s = String(s.dropFirst(7)) }
        if s.hasPrefix("www.") { s = String(s.dropFirst(4)) }
        s = s.components(separatedBy: "/").first ?? s
        return s
    }
}

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

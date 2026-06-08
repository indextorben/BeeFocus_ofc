import Foundation

final class MacCloudSettingsSync {
    static let shared = MacCloudSettingsSync()

    private let store    = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private var isPulling = false

    // Einfache Schlüssel: letzter Schreiber gewinnt
    private let simpleKeys: [String] = [
        "darkModeEnabled",
        "showPastTasksGlobal",
        "filterCurrentMonthOnly",
        "aktivesStatistikThema",
        "aktiverTimerModus",
        "aktivePriorityStyle",
        "konfettiEnabled",
        "dailyFocusGoalMinutes",
        "focusTime",
        "shortBreakTime",
        "longBreakTime",
        "sessionsUntilLongBreak",
        "selectedLanguage",
        "mac_soundEnabled",
        "mac_autoStartBreaks",
        "mac_notifyOnComplete",
        "wasserTagesziel",
    ]

    // Punkte-Schlüssel: höchster Wert gewinnt
    private let maxKeys: [String] = [
        "fokuspunktePeak",
        "fokuspunkteAusgegeben",
    ]

    // Komma-getrennte Sets: Vereinigung (kein gekauftes Item geht verloren)
    private let unionKeys: [String] = [
        "freigeschalteteItems",
    ]

    private var allKeys: [String] { simpleKeys + maxKeys + unionKeys }

    private init() {}

    func forceSync() {
        store.synchronize()
        pullFromCloud()
    }

    func start() {
        store.synchronize()
        pullFromCloud()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(localDidChange),
            name: UserDefaults.didChangeNotification,
            object: defaults
        )
    }

    // MARK: - Pull: iCloud → UserDefaults

    func pullFromCloud() {
        isPulling = true
        defer { isPulling = false }

        for key in simpleKeys {
            guard let value = store.object(forKey: key) else { continue }
            defaults.set(value, forKey: key)
        }
        for key in maxKeys {
            guard let cloudValue = store.object(forKey: key) as? Int else { continue }
            let localValue = defaults.integer(forKey: key)
            if cloudValue > localValue { defaults.set(cloudValue, forKey: key) }
        }
        for key in unionKeys {
            guard let cloudString = store.string(forKey: key) else { continue }
            let cloudSet = Set(cloudString.components(separatedBy: ",").filter { !$0.isEmpty })
            let localSet = Set((defaults.string(forKey: key) ?? "").components(separatedBy: ",").filter { !$0.isEmpty })
            let merged   = localSet.union(cloudSet)
            if merged != localSet { defaults.set(merged.joined(separator: ","), forKey: key) }
        }
    }

    // MARK: - Push: UserDefaults → iCloud

    @objc private func localDidChange() {
        guard !isPulling else { return }

        for key in simpleKeys {
            guard let value = defaults.object(forKey: key) else { continue }
            store.set(value, forKey: key)
        }
        for key in maxKeys {
            let localValue = defaults.integer(forKey: key)
            guard localValue > 0 else { continue }
            let cloudValue = (store.object(forKey: key) as? Int) ?? 0
            store.set(max(localValue, cloudValue), forKey: key)
        }
        for key in unionKeys {
            let localSet = Set((defaults.string(forKey: key) ?? "").components(separatedBy: ",").filter { !$0.isEmpty })
            guard !localSet.isEmpty else { continue }
            let cloudSet = Set((store.string(forKey: key) ?? "").components(separatedBy: ",").filter { !$0.isEmpty })
            store.set(localSet.union(cloudSet).joined(separator: ","), forKey: key)
        }
        store.synchronize()
    }

    // MARK: - iCloud → UserDefaults (externes Gerät hat geändert)

    @objc private func cloudDidChange(_ notification: Notification) {
        guard let changed = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }

        isPulling = true
        defer { isPulling = false }

        for key in changed {
            if simpleKeys.contains(key) {
                if let value = store.object(forKey: key) { defaults.set(value, forKey: key) }
            } else if maxKeys.contains(key) {
                if let cloudValue = store.object(forKey: key) as? Int {
                    let localValue = defaults.integer(forKey: key)
                    if cloudValue > localValue { defaults.set(cloudValue, forKey: key) }
                }
            } else if unionKeys.contains(key) {
                if let cloudString = store.string(forKey: key) {
                    let cloudSet = Set(cloudString.components(separatedBy: ",").filter { !$0.isEmpty })
                    let localSet = Set((defaults.string(forKey: key) ?? "").components(separatedBy: ",").filter { !$0.isEmpty })
                    defaults.set(localSet.union(cloudSet).joined(separator: ","), forKey: key)
                }
            }
        }
    }
}

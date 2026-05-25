import Foundation

final class CloudSettingsSync {
    static let shared = CloudSettingsSync()

    private let store = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private var isPulling = false

    // Einfache Schlüssel: letzter Schreiber gewinnt
    private let simpleKeys: [String] = [
        "darkModeEnabled",
        "notificationsEnabled",
        "showPastTasksGlobal",
        "filterCurrentMonthOnly",
        "autoDeleteCompletedEnabled",
        "autoDeleteCompletedDays",
        "skipOverdueOnImport",
        "autoCalendarSyncEnabled",
        "autoCalendarSyncRange",
        "morningSummaryEnabled",
        "morningSummaryTime",
        "selectedLanguage",
        "aktivesStatistikThema",
        "aktiverTimerModus",
        "aktivePriorityStyle",
        "konfettiEnabled",
        "fokusSperrmodus",
        "dailyFocusGoalMinutes",
        "focusTime",
        "shortBreakTime",
        "longBreakTime",
        "sessionsUntilLongBreak",
        "folderOrderString",
        "collapsedSectionsString",
        "trashMaxCount",
        "trashMaxDays",
        "dailyGoalEnabled",
        "fokusStreakEnabled",
        "fokusZitatEnabled",
        "wochenrueckblickEnabled",
    ]

    // Punkte-Schlüssel: höchster Wert gewinnt (Punkte können nicht sinken)
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

    private func pullFromCloud() {
        isPulling = true
        defer { isPulling = false }

        for key in simpleKeys {
            guard let value = store.object(forKey: key) else { continue }
            defaults.set(value, forKey: key)
        }

        for key in maxKeys {
            guard let cloudValue = store.object(forKey: key) as? Int else { continue }
            let localValue = defaults.integer(forKey: key)
            if cloudValue > localValue {
                defaults.set(cloudValue, forKey: key)
            }
        }

        for key in unionKeys {
            guard let cloudString = store.string(forKey: key) else { continue }
            let cloudSet  = Set(cloudString.components(separatedBy: ",").filter { !$0.isEmpty })
            let localStr  = defaults.string(forKey: key) ?? ""
            let localSet  = Set(localStr.components(separatedBy: ",").filter { !$0.isEmpty })
            let merged    = localSet.union(cloudSet)
            if merged != localSet {
                defaults.set(merged.joined(separator: ","), forKey: key)
            }
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
            let localStr  = defaults.string(forKey: key) ?? ""
            let localSet  = Set(localStr.components(separatedBy: ",").filter { !$0.isEmpty })
            guard !localSet.isEmpty else { continue }
            let cloudStr  = store.string(forKey: key) ?? ""
            let cloudSet  = Set(cloudStr.components(separatedBy: ",").filter { !$0.isEmpty })
            let merged    = localSet.union(cloudSet)
            store.set(merged.joined(separator: ","), forKey: key)
        }

        store.synchronize()
    }

    // MARK: - Cloud → UserDefaults (externes Gerät hat geändert)

    @objc private func cloudDidChange(_ notification: Notification) {
        guard let changed = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }

        isPulling = true
        defer { isPulling = false }

        for key in changed {
            if simpleKeys.contains(key) {
                if let value = store.object(forKey: key) {
                    defaults.set(value, forKey: key)
                }
            } else if maxKeys.contains(key) {
                if let cloudValue = store.object(forKey: key) as? Int {
                    let localValue = defaults.integer(forKey: key)
                    if cloudValue > localValue {
                        defaults.set(cloudValue, forKey: key)
                    }
                }
            } else if unionKeys.contains(key) {
                if let cloudString = store.string(forKey: key) {
                    let cloudSet = Set(cloudString.components(separatedBy: ",").filter { !$0.isEmpty })
                    let localStr = defaults.string(forKey: key) ?? ""
                    let localSet = Set(localStr.components(separatedBy: ",").filter { !$0.isEmpty })
                    let merged   = localSet.union(cloudSet)
                    defaults.set(merged.joined(separator: ","), forKey: key)
                }
            }
        }
    }
}

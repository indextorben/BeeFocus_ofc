import Foundation

final class CloudSettingsSync {
    static let shared = CloudSettingsSync()

    private let store = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard

    private let keys: [String] = [
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
        "fokuspunktePeak",
        "aktivesStatistikThema",
        "selectedLanguage",
        "focusTime",
        "shortBreakTime",
        "longBreakTime",
        "sessionsUntilLongBreak",
        "folderOrderString",
    ]

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

    private func pullFromCloud() {
        for key in keys {
            guard let value = store.object(forKey: key) else { continue }
            defaults.set(value, forKey: key)
        }
    }

    @objc private func cloudDidChange(_ notification: Notification) {
        guard let changed = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
        for key in changed where keys.contains(key) {
            if let value = store.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
    }

    @objc private func localDidChange() {
        for key in keys {
            guard let value = defaults.object(forKey: key) else { continue }
            store.set(value, forKey: key)
        }
        store.synchronize()
    }
}

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

    private let store = ManagedSettingsStore()

    private init() {
        isFocusModeActive = UserDefaults.standard.bool(forKey: "focusModeActive")
        if let data = UserDefaults.standard.data(forKey: "focusModeSelection"),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = decoded
        }
        checkAuthorizationStatus()
    }

    var selectedAppCount: Int { selection.applicationTokens.count }
    var selectedCategoryCount: Int { selection.categoryTokens.count }
    var hasSelection: Bool { !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty }

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

    func enableFocusMode() {
        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        isFocusModeActive = true
        UserDefaults.standard.set(true, forKey: "focusModeActive")
    }

    func disableFocusMode() {
        store.clearAllSettings()
        isFocusModeActive = false
        UserDefaults.standard.set(false, forKey: "focusModeActive")
    }

    func saveSelection() {
        if let data = try? JSONEncoder().encode(selection) {
            UserDefaults.standard.set(data, forKey: "focusModeSelection")
        }
    }
}

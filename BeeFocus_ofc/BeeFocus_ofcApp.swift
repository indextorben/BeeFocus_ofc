//
//  BeeFocus_ofcApp.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 15.06.25.
//

import SwiftUI
import UIKit

@main
struct BeeFocus_ofcApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("darkModeEnabled") private var darkModeEnabled = true
    @AppStorage("selectedLanguage") private var selectedLanguage = "Deutsch"

    @State private var showOnboarding: Bool = !AppStateManager.hasCompletedOnboarding
    @State private var showTutorial: Bool = false

    @State private var nfcToastVisible = false
    @State private var nfcToastIcon = "shield.fill"
    @State private var nfcToastText = ""
    @State private var nfcToastDismissTask: Task<Void, Never>? = nil

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appDelegate.todoStore)
                .environmentObject(appDelegate.timerManager)
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView {
                        AppStateManager.hasCompletedOnboarding = true
                        AppStateManager.hasSeenTutorial = true
                        showOnboarding = false
                        showTutorial = true
                    }
                }
                .sheet(isPresented: $showTutorial, onDismiss: {
                    AppStateManager.hasSeenTutorial = true
                }) {
                    FullAppTutorialView()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .overlay(alignment: .top) {
                    if nfcToastVisible {
                        NFCToastBanner(icon: nfcToastIcon, text: nfcToastText)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.top, 8)
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: nfcToastVisible)
        }
    }

    @MainActor
    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "beefocus" else { return }
        let action = url.host?.lowercased() ?? ""
        if #available(iOS 16, *) {
            switch action {
            case "focus":
                FokusModeManager.shared.enableFocusMode()
                showNFCToast(icon: "shield.fill", text: String(localized: "nfc_toast_focus_on"))
            case "stop":
                FokusModeManager.shared.disableFocusMode()
                showNFCToast(icon: "shield.slash.fill", text: String(localized: "nfc_toast_focus_off"))
            case "toggle":
                if FokusModeManager.shared.isFocusModeActive {
                    FokusModeManager.shared.disableFocusMode()
                    showNFCToast(icon: "shield.slash.fill", text: String(localized: "nfc_toast_focus_off"))
                } else {
                    FokusModeManager.shared.enableFocusMode()
                    showNFCToast(icon: "shield.fill", text: String(localized: "nfc_toast_focus_on"))
                }
            default:
                break
            }
        }
    }

    @MainActor
    private func showNFCToast(icon: String, text: String) {
        nfcToastDismissTask?.cancel()
        nfcToastIcon = icon
        nfcToastText = text
        nfcToastVisible = true
        nfcToastDismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            nfcToastVisible = false
        }
    }
}

struct NFCToastBanner: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(.ultraThinMaterial.opacity(0.0))
                .background(
                    Capsule().fill(Color(red: 0.12, green: 0.12, blue: 0.18).opacity(0.92))
                )
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        )
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?

    let todoStore = TodoStore()
    let timerManager = TimerManager.shared

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        PhoneSessionManager.shared.todoStore = todoStore
        todoStore.writeWidgetSnapshot()
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.todoStore.writeWidgetSnapshot()
            PhoneSessionManager.shared.applyPendingWatchCompletions()
        }

        CloudSettingsSync.shared.start()

        NotificationManager.shared.requestAuthorization { granted in
            if !granted {
                print("Benachrichtigungen nicht erlaubt")
            } else {
                print("Benachrichtigungen erlaubt")
            }
        }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let shakeWindow = ShakeDetectingWindow(windowScene: windowScene)
            let rootVC = UIHostingController(rootView:
                RootView()
                    .environmentObject(todoStore)
                    .environmentObject(timerManager)
            )
            shakeWindow.rootViewController = rootVC

            // 📳 Shake detected handler
            shakeWindow.onShakeDetected = {
                print("📳 Shake erkannt in AppDelegate!")
            }

            shakeWindow.makeKeyAndVisible()
            self.window = shakeWindow
        }

        return true
    }
}

struct RootView: View {
    @EnvironmentObject var todoStore: TodoStore
    @EnvironmentObject var timerManager: TimerManager

    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("focusCoachEnabled")     private var focusCoachEnabled: Bool = true

    @State private var showFocusCoach = false
    @State private var coachMinutesWorked = 0

    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    var body: some View {
        ContentView()
            .environmentObject(todoStore)
            .environmentObject(timerManager)
            .overlay {
                FloatingAIButton()
                    .environmentObject(todoStore)
            }
            .sheet(isPresented: $showFocusCoach) {
                FocusCoachSheet(
                    minutesWorked: coachMinutesWorked,
                    todos: todoStore.todos,
                    themeC1: themeC1,
                    themeC2: themeC2
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onReceive(NotificationCenter.default.publisher(for: .focusSessionCompleted)) { note in
                guard focusCoachEnabled else { return }
                guard hasAIKey else { return }
                let minutes = note.userInfo?["minutes"] as? Int ?? 0
                coachMinutesWorked = minutes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showFocusCoach = true
                }
            }
    }

    private var hasAIKey: Bool {
        let provider = UserDefaults.standard.string(forKey: "aiProvider") ?? "gemini"
        switch provider {
        case "openai": return KeychainHelper.load(for: OpenAIService.keychainKey) != nil
        case "groq":   return KeychainHelper.load(for: GroqService.keychainKey) != nil
        default:       return KeychainHelper.load(for: GeminiService.keychainKey) != nil
        }
    }
}

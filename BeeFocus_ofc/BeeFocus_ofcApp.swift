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

    @State private var showTutorial: Bool = !AppStateManager.hasSeenTutorial

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appDelegate.todoStore)
                .environmentObject(appDelegate.timerManager)
                .sheet(isPresented: $showTutorial, onDismiss: {
                    AppStateManager.hasSeenTutorial = true
                }) {
                    FullAppTutorialView() // <-- Dein Tutorial View
                }
        }
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

    var body: some View {
        ContentView()
            .environmentObject(todoStore)
            .environmentObject(timerManager)
    }
}

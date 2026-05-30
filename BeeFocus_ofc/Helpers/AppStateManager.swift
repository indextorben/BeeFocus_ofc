//
//  AppStateManager.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.10.25.
//

import Foundation

struct AppStateManager {
    static let hasSeenTutorialKey = "hasSeenTutorial"
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    static var hasSeenTutorial: Bool {
        get { UserDefaults.standard.bool(forKey: hasSeenTutorialKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasSeenTutorialKey) }
    }

    static var hasCompletedOnboarding: Bool {
        get {
            // Existing users who already saw the tutorial skip onboarding
            if UserDefaults.standard.bool(forKey: hasSeenTutorialKey) &&
               !UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey) {
                UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
            }
            return UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: hasCompletedOnboardingKey) }
    }
}

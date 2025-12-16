//
//  AppStateManager.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.10.25.
//

import Foundation

struct AppStateManager {
    static let hasSeenTutorialKey = "hasSeenTutorial"
    
    static var hasSeenTutorial: Bool {
        get { UserDefaults.standard.bool(forKey: hasSeenTutorialKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasSeenTutorialKey) }
    }
}

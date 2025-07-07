//
//  ShakeDetectingWindow.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.06.25.
//

import Foundation
import UIKit

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

class ShakeDetectingWindow: UIWindow {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
            print("Shake erkannt!")
        }
        super.motionEnded(motion, with: event)
    }
}

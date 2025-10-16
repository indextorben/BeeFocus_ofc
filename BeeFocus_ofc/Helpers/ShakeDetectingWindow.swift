//
//  ShakeDetectingWindow.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 16.10.25.
//

import SwiftUI
import UIKit

/// UIWindow, das Shake-Gesten erkennt
import UIKit

class ShakeDetectingWindow: UIWindow {
    
    /// Closure, die beim Shake ausgeführt wird
    var onShakeDetected: (() -> Void)?

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        
        if motion == .motionShake {
            print("📳 Shake erkannt!")
            onShakeDetected?()
        }
    }
    
    /// Damit die Window Shake-Bewegungen erkennt
    override var canBecomeFirstResponder: Bool {
        true
    }
    
    override func makeKeyAndVisible() {
        super.makeKeyAndVisible()
        self.becomeFirstResponder()
    }
}

/// SwiftUI-Wrapper für ShakeDetectingWindow
struct ShakeDetectingWindowView<Content: View>: UIViewControllerRepresentable {
    let content: Content
    var onShake: () -> Void

    init(onShake: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.onShake = onShake
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIHostingController(rootView: content)
        
        // Suche nach der obersten UIWindow
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let window = ShakeDetectingWindow(windowScene: windowScene)
            window.rootViewController = controller
            window.onShakeDetected = onShake
            window.makeKeyAndVisible()
        }
        
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Nichts nötig
    }
}

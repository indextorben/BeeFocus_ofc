//
//  LottieView.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 07.07.25.
//

import Foundation
import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let name: String
    var loopMode: LottieLoopMode = .loop  // Endlosschleife für nice Effekt
    @Binding var playTrigger: Bool

    class Coordinator: NSObject {
        var parent: LottieView
        let animationView: LottieAnimationView

        init(_ parent: LottieView, animationView: LottieAnimationView) {
            self.parent = parent
            self.animationView = animationView
        }

        func playAnimationIfTriggered() {
            if parent.playTrigger {
                animationView.play { _ in
                    DispatchQueue.main.async {
                        self.parent.playTrigger = false
                    }
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        let animationView = LottieAnimationView(name: name)
        animationView.loopMode = loopMode
        return Coordinator(self, animationView: animationView)
    }

    func makeUIView(context: Context) -> UIView {
        let animationView = context.coordinator.animationView
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode

        let container = UIView()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.widthAnchor.constraint(equalTo: container.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: container.heightAnchor)
        ])

        context.coordinator.playAnimationIfTriggered()

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.playAnimationIfTriggered()
    }
}

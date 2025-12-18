//
//  TimerDisplay.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 16.06.25.
//

import SwiftUI

struct TimerDisplay: View {
    let timeRemaining: TimeInterval
    let isRunning: Bool

    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        VStack(spacing: 5) {
            Text(timeString(from: timeRemaining))
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(
                isRunning
                ? localizer.localizedString(forKey: "timer_running")
                : localizer.localizedString(forKey: "timer_paused")
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }

    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

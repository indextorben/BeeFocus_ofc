//
//  TimerControlButton.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 16.06.25.
//

import Foundation
import SwiftUI
import SwiftData

struct TimerControlButton: View {
    let systemName: String
    let size: CGFloat
    let action: () -> Void
    let isPrimary: Bool
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(isPrimary ? .white : .primary)
                .frame(width: isPrimary ? 80 : 60, height: isPrimary ? 80 : 60)
                .background(
                    Group {
                        if isPrimary {
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            Color.gray.opacity(0.2)
                        }
                    }
                )
                .clipShape(Circle())
                .shadow(color: isPrimary ? .blue.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
        }
    }
}

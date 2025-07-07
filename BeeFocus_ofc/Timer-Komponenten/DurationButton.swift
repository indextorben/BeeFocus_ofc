//
//  DurationButton.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.06.25.
//

import Foundation
import SwiftUI
import SwiftData

struct DurationButton: View {
    let duration: (String, TimeInterval)
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(duration.0)
                .font(.system(.body, design: .rounded))
                .fontWeight(.medium)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if isSelected {
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
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

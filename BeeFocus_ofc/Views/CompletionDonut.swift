//
//  CompletionDonut.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 15.12.25.
//
import SwiftUI

struct CompletionDonut: View {
    let completed: Int
    let total: Int

    private var progress: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    var body: some View {
        ZStack {
            // Hintergrundring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 16)

            // Fortschrittsring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Prozenttext in der Mitte
            VStack {
                Text("\(Int(progress * 100))%")
                    .font(.title)
                    .bold()
                Text("Erledigt")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 160, height: 160)
        .padding()
    }
}

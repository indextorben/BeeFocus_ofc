//
//  TimerLiveActivityLiveActivity.swift
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Attribute Definition
struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var timeRemaining: TimeInterval
        var isBreak: Bool
    }
    
    // Fixed properties
    var sessionNumber: Int
    var totalSessions: Int
}

// MARK: - Live Activity Widget
struct TimerLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            // Lock screen / banner UI
            VStack {
                Text(context.state.timeRemaining.formattedTime())
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text(context.state.isBreak ? "Pause" : "Fokus-Session")
                    .font(.headline)
            }
            .activityBackgroundTint(context.state.isBreak ? .green : .blue)
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("⏱")
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.timeRemaining.formattedTime())
                        .font(.title2)
                        .bold()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.isBreak ? "Pause" : "Fokus")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Session \(context.attributes.sessionNumber)/\(context.attributes.totalSessions)")
                }
            } compactLeading: {
                Text("⏱")
            } compactTrailing: {
                Text("\(Int(context.state.timeRemaining / 60))m")
            } minimal: {
                Text("⏱")
            }
            .widgetURL(URL(string: "beefocus://timer"))
            .keylineTint(.blue)
        }
    }
}

// MARK: - TimeInterval Extensions
extension TimeInterval {
    func formattedTime() -> String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Preview
struct TimerLiveActivityPreviewView: View {
    let timeRemaining: TimeInterval
    let isBreak: Bool
    let sessionNumber: Int
    let totalSessions: Int

    var body: some View {
        VStack {
            Text(timeRemaining.formattedTime())
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text(isBreak ? "Pause" : "Fokus-Session")
                .font(.headline)
            Text("Session \(sessionNumber)/\(totalSessions)")
        }
        .padding()
        .background(isBreak ? Color.green : Color.blue)
        .foregroundColor(.white)
        .cornerRadius(16)
    }
}

// Preview für Xcode
struct TimerLiveActivityLiveActivity_Previews: PreviewProvider {
    static var previews: some View {
        TimerLiveActivityPreviewView(timeRemaining: 600, isBreak: false, sessionNumber: 1, totalSessions: 4)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}

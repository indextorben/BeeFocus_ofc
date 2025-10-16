//
//  TimerLiveActivityLiveActivity.swift
<<<<<<< HEAD
=======
//  TimerLiveActivity
//
//  Created by Torben Lehneke on 16.10.25.
>>>>>>> main
//

import ActivityKit
import WidgetKit
import SwiftUI

<<<<<<< HEAD
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
=======
struct TimerLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TimerLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerLiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
>>>>>>> main
        }
    }
}

<<<<<<< HEAD
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
=======
extension TimerLiveActivityAttributes {
    fileprivate static var preview: TimerLiveActivityAttributes {
        TimerLiveActivityAttributes(name: "World")
    }
}

extension TimerLiveActivityAttributes.ContentState {
    fileprivate static var smiley: TimerLiveActivityAttributes.ContentState {
        TimerLiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TimerLiveActivityAttributes.ContentState {
         TimerLiveActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TimerLiveActivityAttributes.preview) {
   TimerLiveActivityLiveActivity()
} contentStates: {
    TimerLiveActivityAttributes.ContentState.smiley
    TimerLiveActivityAttributes.ContentState.starEyes
>>>>>>> main
}

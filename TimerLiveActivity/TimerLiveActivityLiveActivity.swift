//
//  TimerLiveActivityLiveActivity.swift
//  TimerLiveActivity
//
//  Created by Torben Lehneke on 16.10.25.
//

import ActivityKit
import WidgetKit
import SwiftUI

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
        }
    }
}

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
}

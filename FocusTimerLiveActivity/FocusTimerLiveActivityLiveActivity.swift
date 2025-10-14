//
//  FocusTimerLiveActivityLiveActivity.swift
//  FocusTimerLiveActivity
//
//  Created by Torben Lehneke on 10.10.25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FocusTimerLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FocusTimerLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusTimerLiveActivityAttributes.self) { context in
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

extension FocusTimerLiveActivityAttributes {
    fileprivate static var preview: FocusTimerLiveActivityAttributes {
        FocusTimerLiveActivityAttributes(name: "World")
    }
}

extension FocusTimerLiveActivityAttributes.ContentState {
    fileprivate static var smiley: FocusTimerLiveActivityAttributes.ContentState {
        FocusTimerLiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FocusTimerLiveActivityAttributes.ContentState {
         FocusTimerLiveActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FocusTimerLiveActivityAttributes.preview) {
   FocusTimerLiveActivityLiveActivity()
} contentStates: {
    FocusTimerLiveActivityAttributes.ContentState.smiley
    FocusTimerLiveActivityAttributes.ContentState.starEyes
}

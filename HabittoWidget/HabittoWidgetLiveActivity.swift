//
//  HabittoWidgetLiveActivity.swift
//  HabittoWidget
//
//  Created by Chloe Lee on 2026-01-10.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct HabittoWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct HabittoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HabittoWidgetAttributes.self) { context in
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

extension HabittoWidgetAttributes {
    fileprivate static var preview: HabittoWidgetAttributes {
        HabittoWidgetAttributes(name: "World")
    }
}

extension HabittoWidgetAttributes.ContentState {
    fileprivate static var smiley: HabittoWidgetAttributes.ContentState {
        HabittoWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: HabittoWidgetAttributes.ContentState {
         HabittoWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: HabittoWidgetAttributes.preview) {
   HabittoWidgetLiveActivity()
} contentStates: {
    HabittoWidgetAttributes.ContentState.smiley
    HabittoWidgetAttributes.ContentState.starEyes
}

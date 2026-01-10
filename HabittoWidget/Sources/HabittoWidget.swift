//
//  HabittoWidget.swift
//  HabittoWidget
//
//  Main widget configuration
//

import WidgetKit
import SwiftUI

/// Main habit tracking widget
struct HabittoWidget: Widget {
    let kind: String = "HabittoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitWidgetProvider()) { entry in
            HabitWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Habit Tracker")
        .description("View your habits, completion status, and streaks on your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

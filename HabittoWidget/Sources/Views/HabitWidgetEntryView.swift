//
//  HabitWidgetEntryView.swift
//  HabittoWidget
//
//  Main widget entry view that routes to appropriate size-specific views
//

import SwiftUI
import WidgetKit

/// Main widget view that selects the appropriate layout based on widget family
struct HabitWidgetEntryView: View {
    var entry: HabitWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            // Fallback to small view for unsupported sizes
            SmallWidgetView(entry: entry)
        }
    }
}

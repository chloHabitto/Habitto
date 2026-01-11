//
//  HabittoWidget.swift
//  HabittoWidget
//
//  Created by Chloe Lee on 2026-01-11.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), currentStreak: 7)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let streak = getCurrentStreak()
        let entry = SimpleEntry(date: Date(), currentStreak: streak)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Read the latest streak value
        let currentDate = Date()
        let streak = getCurrentStreak()
        
        // Create entries for the next few hours, all using the same streak value
        // The timeline will refresh more frequently to pick up changes
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, currentStreak: streak)
            entries.append(entry)
        }

        // Use .after with a shorter refresh interval to pick up changes faster
        // Refresh every 15 minutes instead of waiting until timeline ends (5 hours)
        // This ensures the widget displays updated streak values quickly
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func getCurrentStreak() -> Int {
        // Read streak from App Group UserDefaults (shared with main app)
        // Use App Group to access data shared between app and widget extension
        if let sharedDefaults = UserDefaults(suiteName: "group.com.habitto.widget") {
            // Force synchronize to ensure we read the latest value
            sharedDefaults.synchronize()
            let streak = sharedDefaults.integer(forKey: "widgetCurrentStreak")
            // Log for debugging (only in debug builds)
            #if DEBUG
            print("📱 WIDGET: Read streak from App Group: \(streak)")
            #endif
            return streak
        } else {
            // Fallback to standard UserDefaults if App Group is not available
            // This should not happen if entitlements are configured correctly
            #if DEBUG
            print("⚠️ WIDGET: App Group not available, using standard UserDefaults")
            #endif
            UserDefaults.standard.synchronize()
            return UserDefaults.standard.integer(forKey: "widgetCurrentStreak")
        }
    }

//    func relevances() async -> WidgetRelevances<Void> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
}

struct HabittoWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(currentStreak: entry.currentStreak)
        default:
            VStack {
                Text("Time:")
                Text(entry.date, style: .time)
                
                Text("Streak:")
                Text("\(entry.currentStreak)")
            }
        }
    }
}

struct SmallWidgetView: View {
    let currentStreak: Int
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Streak info at top left
            VStack(alignment: .leading, spacing: 0) {
                Text("\(currentStreak)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(Color("appText01"))
                
                Text("Streak Days")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("appText05"))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // Fire icon at bottom right
            // Using SF Symbol instead of large PNG image for widget compatibility
            Image(systemName: "flame.fill")
                .font(.system(size: 56, weight: .medium))
                .foregroundColor(Color("appText01"))
        }
        .padding(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
    }
}

struct HabittoWidget: Widget {
    let kind: String = "HabittoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                HabittoWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                HabittoWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    HabittoWidget()
} timeline: {
    SimpleEntry(date: .now, currentStreak: 7)
    SimpleEntry(date: .now, currentStreak: 14)
}

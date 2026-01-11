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

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        let streak = getCurrentStreak()
        
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, currentStreak: streak)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func getCurrentStreak() -> Int {
        // Read streak from UserDefaults
        // Key should match what the app writes to
        return UserDefaults.standard.integer(forKey: "widgetCurrentStreak")
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
            Image("Icon-fire")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
        }
        .padding()
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
    }
}

#Preview(as: .systemSmall) {
    HabittoWidget()
} timeline: {
    SimpleEntry(date: .now, currentStreak: 7)
    SimpleEntry(date: .now, currentStreak: 14)
}

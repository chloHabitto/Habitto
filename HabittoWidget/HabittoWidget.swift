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
        print("🔴 Provider.getSnapshot: Created entry with streak = \(streak), entry.currentStreak = \(entry.currentStreak)")
        NSLog("🔴 Provider.getSnapshot: Created entry with streak = %d, entry.currentStreak = %d", streak, entry.currentStreak)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Read the latest streak value
        let currentDate = Date()
        let streak = getCurrentStreak()
        print("🔴 Provider.getTimeline: Read streak = \(streak), creating entries")
        NSLog("🔴 Provider.getTimeline: Read streak = %d, creating entries", streak)
        
        // Create entries for the next few hours, all using the same streak value
        // The timeline will refresh more frequently to pick up changes
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, currentStreak: streak)
            entries.append(entry)
            print("🔴 Provider.getTimeline: Created entry with streak = \(streak) for date \(entryDate)")
        }

        // Use .after with a shorter refresh interval to pick up changes faster
        // Refresh every 15 minutes instead of waiting until timeline ends (5 hours)
        // This ensures the widget displays updated streak values quickly
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        print("🔴 Provider.getTimeline: Completing timeline with \(entries.count) entries, all with streak = \(streak)")
        completion(timeline)
    }
    
    private func getCurrentStreak() -> Int {
        // Read streak from App Group UserDefaults (shared with main app)
        // Use App Group to access data shared between app and widget extension
        if let sharedDefaults = UserDefaults(suiteName: "group.com.habitto.widget") {
            // Force synchronize to ensure we read the latest value
            sharedDefaults.synchronize()
            
            // Verify the key exists
            if sharedDefaults.object(forKey: "widgetCurrentStreak") == nil {
                print("⚠️ WIDGET getCurrentStreak: Key 'widgetCurrentStreak' does NOT exist in App Group!")
                NSLog("⚠️ WIDGET getCurrentStreak: Key 'widgetCurrentStreak' does NOT exist in App Group!")
                return 0
            }
            
            let streak = sharedDefaults.integer(forKey: "widgetCurrentStreak")
            // Log for debugging (always log, not just in debug builds)
            print("📱 WIDGET getCurrentStreak: Read streak from App Group = \(streak)")
            NSLog("📱 WIDGET getCurrentStreak: Read streak from App Group = %d", streak)
            
            // Also print raw value to verify
            if let rawValue = sharedDefaults.object(forKey: "widgetCurrentStreak") {
                print("📱 WIDGET getCurrentStreak: Raw value type = \(type(of: rawValue)), value = \(rawValue)")
            }
            
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
    
    init(date: Date, currentStreak: Int) {
        self.date = date
        self.currentStreak = currentStreak
        print("🔴 SimpleEntry: INIT with date = \(date), currentStreak = \(currentStreak)")
        NSLog("🔴 SimpleEntry: INIT with currentStreak = %d", currentStreak)
    }
}

struct HabittoWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    init(entry: Provider.Entry) {
        self.entry = entry
        print("🔴 HabittoWidgetEntryView: INIT with entry streak = \(entry.currentStreak)")
        NSLog("🔴 HabittoWidgetEntryView: INIT with entry streak = %d", entry.currentStreak)
    }

    var body: some View {
        // Log every time body is computed
        print("🔴 HabittoWidgetEntryView: body computed with entry streak = \(entry.currentStreak)")
        NSLog("🔴 HabittoWidgetEntryView: body computed with entry streak = %d", entry.currentStreak)
        
        return Group {
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
}

struct SmallWidgetView: View {
    let currentStreak: Int
    
    init(currentStreak: Int) {
        self.currentStreak = currentStreak
        print("🔴 SmallWidgetView: INIT with streak = \(currentStreak)")
        NSLog("🔴 SmallWidgetView: INIT with streak = %d", currentStreak)
    }
    
    var body: some View {
        // Log every time body is computed
        print("🔴 SmallWidgetView: body computed with streak = \(currentStreak)")
        NSLog("🔴 SmallWidgetView: body computed with streak = %d", currentStreak)
        
        return ZStack(alignment: .bottomTrailing) {
            // Streak info at top left
            VStack(alignment: .leading, spacing: 0) {
                Text("\(currentStreak)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(Color("appText01"))
                    .onAppear {
                        print("🔴 SmallWidgetView: Text view appeared with streak = \(currentStreak)")
                        NSLog("🔴 SmallWidgetView: Text view appeared with streak = %d", currentStreak)
                    }
                
                Text("Streak Days")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("appText05"))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // Fire icon at bottom right
            Image("Widget-Icon-Fire")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
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

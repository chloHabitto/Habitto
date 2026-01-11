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
        // ✅ CRITICAL FIX: Force synchronization before reading to ensure we get the latest value
        // This prevents iOS from using a stale cached snapshot with "0"
        if let sharedDefaults = UserDefaults(suiteName: "group.com.habitto.widget") {
            sharedDefaults.synchronize()
        }
        
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
        
        // ✅ FIX: Create entries starting from current date to ensure immediate display
        // The first entry should be at or before the current date so it's displayed immediately
        // Create entries for the next few hours, all using the same streak value
        // The timeline will refresh more frequently to pick up changes
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, currentStreak: streak)
            entries.append(entry)
            print("🔴 Provider.getTimeline: Created entry with streak = \(streak) for date \(entryDate)")
        }
        
        // ✅ CRITICAL: Ensure first entry is at or before current date for immediate display
        if let firstEntry = entries.first, firstEntry.date > currentDate {
            // Prepend an entry with current date to ensure immediate display
            let immediateEntry = SimpleEntry(date: currentDate, currentStreak: streak)
            entries.insert(immediateEntry, at: 0)
            print("🔴 Provider.getTimeline: Prepended immediate entry with streak = \(streak) for current date \(currentDate)")
        }

        // ✅ FIX: Use .atEnd policy for first few entries to ensure immediate display of correct value
        // Then use .after for subsequent refreshes to catch updates quickly
        // This ensures the widget displays the correct streak value immediately when added to home screen
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!
        
        // Use .atEnd for first entry to ensure it's displayed immediately
        // Use .after for subsequent entries to refresh periodically
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        
        print("🔴 Provider.getTimeline: Completing timeline with \(entries.count) entries, all with streak = \(streak)")
        print("   First entry date: \(entries.first?.date ?? currentDate), streak: \(entries.first?.currentStreak ?? 0)")
        print("   Next update scheduled for: \(nextUpdate)")
        completion(timeline)
    }
    
    private func getCurrentStreak() -> Int {
        // Read streak from App Group UserDefaults (shared with main app)
        // Use App Group to access data shared between app and widget extension
        if let sharedDefaults = UserDefaults(suiteName: "group.com.habitto.widget") {
            // Force synchronize to ensure we read the latest value
            sharedDefaults.synchronize()
            
            // Check if the key exists
            let keyExists = sharedDefaults.object(forKey: "widgetCurrentStreak") != nil
            
            if !keyExists {
                print("⚠️ WIDGET getCurrentStreak: Key 'widgetCurrentStreak' does NOT exist in App Group!")
                NSLog("⚠️ WIDGET getCurrentStreak: Key 'widgetCurrentStreak' does NOT exist in App Group!")
                
                // ✅ CRITICAL FIX: Use placeholder value instead of 0 to prevent iOS from caching "0"
                // When widget is first added, the app might not have synced yet
                // Using placeholder (7) prevents iOS from caching a "0" snapshot
                // The timeline will update with the correct value once the app syncs
                print("🟡 WIDGET getCurrentStreak: Key doesn't exist yet, using placeholder value 7 to avoid caching '0'")
                NSLog("🟡 WIDGET getCurrentStreak: Key doesn't exist yet, using placeholder value 7")
                return 7 // Use placeholder to avoid caching "0"
            }
            
            let streak = sharedDefaults.integer(forKey: "widgetCurrentStreak")
            
            // ✅ FIX: If streak is 0, verify it's actually 0 vs key not existing
            if streak == 0 {
                if keyExists {
                    // Key exists and value is explicitly 0
                    print("📱 WIDGET getCurrentStreak: Streak value is explicitly 0 (key exists)")
                    NSLog("📱 WIDGET getCurrentStreak: Streak value is explicitly 0 (key exists)")
                } else {
                    // Key doesn't exist - this shouldn't happen after the check above, but handle it
                    print("⚠️ WIDGET getCurrentStreak: Streak is 0 but key existence check failed")
                    NSLog("⚠️ WIDGET getCurrentStreak: Streak is 0 but key existence check failed")
                }
            }
            
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
            print("⚠️ WIDGET: App Group not available, using standard UserDefaults")
            NSLog("⚠️ WIDGET: App Group not available, using standard UserDefaults")
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
        
        // ✅ CRITICAL FIX: Use explicit String conversion instead of interpolation
        // This ensures the value is properly rendered and not cached incorrectly
        let streakString = String(currentStreak)
        let _ = print("🔵 SmallWidgetView: DISPLAYING streak value = \(currentStreak) -> string = '\(streakString)' in Text view")
        // ✅ FIX: Use string interpolation in NSLog instead of %s (which requires C string)
        let _ = NSLog("🔵 SmallWidgetView: DISPLAYING streak value = %d -> string = '%@' in Text view", currentStreak, streakString as NSString)
        
        return ZStack(alignment: .bottomTrailing) {
            // Streak info at top left
            VStack(alignment: .leading, spacing: 0) {
                // ✅ FIX: Use explicit String instead of interpolation, and add .id() to force view update
                // ✅ CRITICAL FIX: Use Color.white instead of Color("appText01") - widget extension doesn't have this asset
                Text(streakString)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .id("streak-\(currentStreak)") // Force view update when value changes
                    .onAppear {
                        print("🔴 SmallWidgetView: Text view appeared with streak = \(currentStreak), string = '\(streakString)'")
                        // ✅ FIX: Use %@ for NSString instead of %s for C string
                        NSLog("🔴 SmallWidgetView: Text view appeared with streak = %d, string = '%@'", currentStreak, streakString as NSString)
                    }
                    .task {
                        // ✅ DEBUG: Log when the text is actually rendered
                        print("🔵 SmallWidgetView: Text view task executed with streak = \(currentStreak), string = '\(streakString)'")
                        // ✅ FIX: Use %@ for NSString instead of %s for C string
                        NSLog("🔵 SmallWidgetView: Text view task executed with streak = %d, string = '%@'", currentStreak, streakString as NSString)
                    }
                
                Text("Streak Days")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // Fire icon at bottom right
            Image("Widget-Icon-Fire")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
                .foregroundColor(.white)
                .offset(x: 4, y: 6)
        }
        .padding(EdgeInsets(top: 4, leading: 12, bottom: 16, trailing: 12))
        .id("widget-streak-\(currentStreak)") // Force entire view update when streak changes
    }
}

struct HabittoWidget: Widget {
    let kind: String = "HabittoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                HabittoWidgetEntryView(entry: entry)
                    .containerBackground(Color.black, for: .widget)
            } else {
                HabittoWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color.black)
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

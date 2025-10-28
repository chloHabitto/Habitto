import Foundation
import SwiftData

/// Debug tool to investigate where habits are stored
@MainActor
class HabitInvestigator {
  
  static let shared = HabitInvestigator()
  
  /// Investigate where a specific habit is stored
  func investigate(habitName: String) {
    print("\n🔍 ════════════════════════════════════════════════════════")
    print("🔍 INVESTIGATION: Looking for '\(habitName)' everywhere...")
    print("🔍 ════════════════════════════════════════════════════════\n")
    
    // Check 1: HabitRepository published array
    print("1️⃣ Checking HabitRepository.shared.habits (in-memory @Published array):")
    let inPublishedArray = HabitRepository.shared.habits.first { $0.name == habitName }
    print("   Found: \(inPublishedArray != nil ? "✅ YES" : "❌ NO")")
    if let habit = inPublishedArray {
      print("   → ID: \(habit.id)")
      print("   → Start Date: \(habit.startDate)")
      print("   → End Date: \(habit.endDate?.description ?? "nil")")
    }
    print("   → Total habits in published array: \(HabitRepository.shared.habits.count)")
    print("")
    
    // Check 2: SwiftData ModelContext
    print("2️⃣ Checking SwiftData ModelContext (database):")
    do {
      let container = SwiftDataContainer.shared.modelContainer
      let context = container.mainContext
      
      // Fetch all HabitData without any filtering
      let allHabitsDescriptor = FetchDescriptor<HabitData>(
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
      )
      let allHabitData = try context.fetch(allHabitsDescriptor)
      print("   → Total HabitData records in SwiftData: \(allHabitData.count)")
      
      // Look for our specific habit
      let foundHabitData = allHabitData.first { $0.name == habitName }
      print("   Found: \(foundHabitData != nil ? "✅ YES" : "❌ NO")")
      if let habitData = foundHabitData {
        print("   → ID: \(habitData.id)")
        print("   → Name: \(habitData.name)")
        print("   → Start Date: \(habitData.startDate)")
        print("   → End Date: \(habitData.endDate?.description ?? "nil")")
        print("   → User ID: \(habitData.userId)")
      }
      
      // Show all habit names in database
      print("   → All habit names in SwiftData:")
      for (index, habitData) in allHabitData.enumerated() {
        print("      [\(index)] '\(habitData.name)' (start: \(habitData.startDate))")
      }
    } catch {
      print("   ❌ ERROR fetching from SwiftData: \(error.localizedDescription)")
    }
    print("")
    
    // Check 3: UserDefaults (if used)
    print("3️⃣ Checking UserDefaults:")
    let userDefaultsKeys = ["habits", "habits_key", "cached_habits", "HabitStore_habits"]
    var foundInUserDefaults = false
    for key in userDefaultsKeys {
      if let data = UserDefaults.standard.data(forKey: key) {
        print("   → Found data for key '\(key)'")
        // Try to decode as array of habits
        if let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
          let found = decoded.first { $0.name == habitName }
          if found != nil {
            print("   Found: ✅ YES in key '\(key)'")
            print("   → Habit: \(found!)")
            foundInUserDefaults = true
          }
        }
      }
    }
    if !foundInUserDefaults {
      print("   Found: ❌ NO in any UserDefaults keys")
    }
    print("")
    
    // Check 4: HabitStore (if accessible)
    print("4️⃣ Checking HabitStore actor (if accessible):")
    print("   ⚠️ Cannot directly access actor state from main thread")
    print("   → You'll need to add debug logging in HabitStore itself")
    print("")
    
    // Summary
    print("📊 ════════════════════════════════════════════════════════")
    print("📊 SUMMARY:")
    print("📊 ════════════════════════════════════════════════════════")
    print("   Published array (in-memory): \(HabitRepository.shared.habits.count) habits")
    do {
      let container = SwiftDataContainer.shared.modelContainer
      let context = container.mainContext
      let allHabitsDescriptor = FetchDescriptor<HabitData>()
      let allHabitData = try context.fetch(allHabitsDescriptor)
      print("   SwiftData (database): \(allHabitData.count) habits")
    } catch {
      print("   SwiftData: ERROR - \(error.localizedDescription)")
    }
    print("📊 ════════════════════════════════════════════════════════\n")
  }
  
  /// Investigate all habits in all storage locations
  func investigateAll() {
    print("\n🔍 ════════════════════════════════════════════════════════")
    print("🔍 FULL INVESTIGATION: All habits in all storage locations")
    print("🔍 ════════════════════════════════════════════════════════\n")
    
    // 1. Published array
    print("1️⃣ HabitRepository.shared.habits (in-memory @Published):")
    print("   Count: \(HabitRepository.shared.habits.count)")
    for (index, habit) in HabitRepository.shared.habits.enumerated() {
      print("   [\(index)] '\(habit.name)' - Start: \(habit.startDate)")
    }
    print("")
    
    // 2. SwiftData
    print("2️⃣ SwiftData ModelContext (database):")
    do {
      let container = SwiftDataContainer.shared.modelContainer
      let context = container.mainContext
      let allHabitsDescriptor = FetchDescriptor<HabitData>(
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
      )
      let allHabitData = try context.fetch(allHabitsDescriptor)
      print("   Count: \(allHabitData.count)")
      for (index, habitData) in allHabitData.enumerated() {
        print("   [\(index)] '\(habitData.name)' - Start: \(habitData.startDate), User: \(habitData.userId)")
      }
    } catch {
      print("   ERROR: \(error.localizedDescription)")
    }
    print("")
    
    print("🔍 ════════════════════════════════════════════════════════\n")
  }
}


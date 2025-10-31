import Foundation
import SwiftUI

/// Feature flags for controlling new architecture rollout
///
/// **Usage:**
/// ```swift
/// if NewArchitectureFlags.shared.useNewProgressTracking {
///     // Use new services
/// } else {
///     // Use old system
/// }
/// ```
///
/// **Rollout Strategy:**
/// 1. Start with all flags OFF
/// 2. Enable for test accounts only
/// 3. Monitor for issues
/// 4. Gradually roll out to all users
@MainActor
class NewArchitectureFlags: ObservableObject {
    // MARK: - Singleton
    
    static let shared = NewArchitectureFlags()
    
    // MARK: - Feature Flags
    
    /// Master switch - enables all new features at once
    @Published var useNewArchitecture = false {
        didSet {
            if useNewArchitecture {
                // Enable all subsystems
                useNewProgressTracking = true
                useNewStreakCalculation = true
                useNewXPSystem = true
                print("🚀 NewArchitectureFlags: NEW ARCHITECTURE ENABLED")
            } else {
                print("📦 NewArchitectureFlags: Using legacy system")
            }
            saveFlags()
        }
    }
    
    /// Use new ProgressService for habit completion tracking
    @Published var useNewProgressTracking = false {
        didSet {
            if useNewProgressTracking {
                print("✅ NewArchitectureFlags: New progress tracking ENABLED")
            }
            if !useNewArchitecture {
                saveFlags()
            }
        }
    }
    
    /// Use new StreakService for global streak calculation
    @Published var useNewStreakCalculation = false {
        didSet {
            if useNewStreakCalculation {
                print("🔥 NewArchitectureFlags: New streak calculation ENABLED")
            }
            if !useNewArchitecture {
                saveFlags()
            }
        }
    }
    
    /// Use new XPService for XP and leveling
    @Published var useNewXPSystem = false {
        didSet {
            if useNewXPSystem {
                print("⭐ NewArchitectureFlags: New XP system ENABLED")
            }
            if !useNewArchitecture {
                saveFlags()
            }
        }
    }
    
    /// Use event sourcing for progress tracking
    @Published var useEventSourcing = false {
        didSet {
            if useEventSourcing {
                print("✅ NewArchitectureFlags: Event sourcing ENABLED")
            } else {
                print("📦 NewArchitectureFlags: Using direct progress updates")
            }
            if !useNewArchitecture {
                saveFlags()
            }
        }
    }
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let newArchitecture = "feature_newArchitecture"
        static let newProgress = "feature_newProgress"
        static let newStreak = "feature_newStreak"
        static let newXP = "feature_newXP"
        static let eventSourcing = "feature_eventSourcing"
    }
    
    // MARK: - Initialization
    
    private init() {
        loadFlags()
        print("🏁 NewArchitectureFlags: Initialized")
        printStatus()
    }
    
    // MARK: - Persistence
    
    /// Load flags from UserDefaults
    private func loadFlags() {
        useNewArchitecture = UserDefaults.standard.bool(forKey: Keys.newArchitecture)
        useNewProgressTracking = UserDefaults.standard.bool(forKey: Keys.newProgress)
        useNewStreakCalculation = UserDefaults.standard.bool(forKey: Keys.newStreak)
        useNewXPSystem = UserDefaults.standard.bool(forKey: Keys.newXP)
        useEventSourcing = UserDefaults.standard.bool(forKey: Keys.eventSourcing)
    }
    
    /// Save flags to UserDefaults
    func saveFlags() {
        UserDefaults.standard.set(useNewArchitecture, forKey: Keys.newArchitecture)
        UserDefaults.standard.set(useNewProgressTracking, forKey: Keys.newProgress)
        UserDefaults.standard.set(useNewStreakCalculation, forKey: Keys.newStreak)
        UserDefaults.standard.set(useNewXPSystem, forKey: Keys.newXP)
        UserDefaults.standard.set(useEventSourcing, forKey: Keys.eventSourcing)
        print("💾 NewArchitectureFlags: Saved to UserDefaults")
    }
    
    // MARK: - Management
    
    /// Reset all flags to default (OFF)
    func resetToDefaults() {
        useNewArchitecture = false
        useNewProgressTracking = false
        useNewStreakCalculation = false
        useNewXPSystem = false
        useEventSourcing = false
        saveFlags()
        print("🔄 NewArchitectureFlags: Reset to defaults (all OFF)")
    }
    
    /// Enable all new features
    func enableAll() {
        useNewArchitecture = true
        useEventSourcing = true
        print("🚀 NewArchitectureFlags: All features ENABLED")
    }
    
    /// Check if any new features are enabled
    var anyEnabled: Bool {
        return useNewArchitecture ||
               useNewProgressTracking ||
               useNewStreakCalculation ||
               useNewXPSystem ||
               useEventSourcing
    }
    
    /// Get summary of enabled features
    var enabledFeatures: [String] {
        var features: [String] = []
        if useNewArchitecture { features.append("Master Switch") }
        if useNewProgressTracking { features.append("Progress Tracking") }
        if useNewStreakCalculation { features.append("Streak Calculation") }
        if useNewXPSystem { features.append("XP System") }
        if useEventSourcing { features.append("Event Sourcing") }
        return features
    }
    
    // MARK: - Debugging
    
    /// Print current flag status
    func printStatus() {
        print("""
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        🏁 FEATURE FLAGS STATUS
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        🚀 New Architecture:      \(useNewArchitecture ? "✅ ON" : "❌ OFF")
        📊 Progress Tracking:     \(useNewProgressTracking ? "✅ ON" : "❌ OFF")
        🔥 Streak Calculation:    \(useNewStreakCalculation ? "✅ ON" : "❌ OFF")
        ⭐ XP System:             \(useNewXPSystem ? "✅ ON" : "❌ OFF")
        📝 Event Sourcing:        \(useEventSourcing ? "✅ ON" : "❌ OFF")
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        """)
  }
}

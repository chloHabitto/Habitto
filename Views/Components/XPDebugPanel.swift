import SwiftUI
import SwiftData
import Foundation

// MARK: - XP Debug Panel
struct XPDebugPanel: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var xpManager = XPManager.shared
    @State private var debugInfo: XPDebugInfo = XPDebugInfo()
    @State private var isRunningDiagnostic = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("🔍 XP System Debug")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Run Diagnostic") {
                    runDiagnostic()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .disabled(isRunningDiagnostic)
            }
            
            if isRunningDiagnostic {
                ProgressView("Running diagnostic...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                // Debug Information
                VStack(alignment: .leading, spacing: 8) {
                    DebugRow(label: "Current userId:", value: debugInfo.currentUserId)
                    DebugRow(label: "XPManager totalXP:", value: "\(debugInfo.xpManagerTotalXP)")
                    DebugRow(label: "SwiftData totalXP:", value: "\(debugInfo.swiftDataTotalXP)")
                    DebugRow(label: "Sync status:", value: debugInfo.syncStatus, isError: !debugInfo.isInSync)
                    DebugRow(label: "DailyAward count:", value: "\(debugInfo.dailyAwardCount)")
                    DebugRow(label: "Last award date:", value: debugInfo.lastAwardDate)
                    DebugRow(label: "Today's award:", value: debugInfo.todaysAwardStatus, isError: !debugInfo.todaysAwardGranted)
                    DebugRow(label: "Auth status:", value: debugInfo.authStatus, isError: !debugInfo.isAuthenticated)
                    DebugRow(label: "Migration:", value: debugInfo.migrationStatus, isError: !debugInfo.migrationCompleted)
                }
                
                // Action Buttons
                HStack(spacing: 8) {
                    Button("Test Award 100 XP") {
                        testAwardXP()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(6)
                    
                           Button("Test Idempotency") {
                               testIdempotency()
                           }
                           .font(.system(size: 11, weight: .medium))
                           .foregroundColor(.orange)
                           .padding(.horizontal, 8)
                           .padding(.vertical, 4)
                           .background(Color.orange.opacity(0.1))
                           .cornerRadius(6)
                           
                           Button("Show Today's Awards") {
                               showTodaysAwards()
                           }
                           .font(.system(size: 11, weight: .medium))
                           .foregroundColor(.blue)
                           .padding(.horizontal, 8)
                           .padding(.vertical, 4)
                           .background(Color.blue.opacity(0.1))
                           .cornerRadius(6)
                           
                           Button("Level Analysis") {
                               showLevelAnalysis()
                           }
                           .font(.system(size: 11, weight: .medium))
                           .foregroundColor(.purple)
                           .padding(.horizontal, 8)
                           .padding(.vertical, 4)
                           .background(Color.purple.opacity(0.1))
                           .cornerRadius(6)
                           
                           Button("XP Investigation") {
                               investigateXPProgression()
                           }
                           .font(.system(size: 11, weight: .medium))
                           .foregroundColor(.red)
                           .padding(.horizontal, 8)
                           .padding(.vertical, 4)
                           .background(Color.red.opacity(0.1))
                           .cornerRadius(6)
                           
                           Button("Fix XP Bug") {
                               fixXPInflationBug()
                           }
                           .font(.system(size: 11, weight: .medium))
                           .foregroundColor(.orange)
                           .padding(.horizontal, 8)
                           .padding(.vertical, 4)
                           .background(Color.orange.opacity(0.1))
                           .cornerRadius(6)
                    
                    Button("Complete All Habits") {
                        testCompleteAllHabits()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(6)
                    
                    Button("Check Sync") {
                        checkSyncStatus()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(6)
                    
                    Button("Fix Yesterday XP") {
                        fixYesterdayXP()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                    
                    Button("Clear All Data") {
                        clearAllData()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 20)
        .onAppear {
            runDiagnostic()
        }
    }
    
    // MARK: - Debug Actions
    
    private func runDiagnostic() {
        isRunningDiagnostic = true
        
        Task {
            await MainActor.run {
                // Get current userId and auth status
                let userId = getCurrentUserId()
                debugInfo.currentUserId = userId
                
                // Check authentication status
                // Note: AuthenticationManager access needs to be implemented
                debugInfo.isAuthenticated = false
                debugInfo.authStatus = "❌ Auth check not implemented"
                
                // Check migration status
                // Note: XPDataMigration access needs to be implemented
                debugInfo.migrationCompleted = false
                debugInfo.migrationStatus = "❌ Migration check not implemented"
                
                // Get XPManager values
                debugInfo.xpManagerTotalXP = xpManager.userProgress.totalXP
                
                // Query SwiftData for DailyAwards
                let predicate = #Predicate<DailyAward> { award in
                    award.userId == userId
                }
                
                do {
                    let request = FetchDescriptor<DailyAward>(predicate: predicate)
                    let awards = try modelContext.fetch(request)
                    
                    debugInfo.swiftDataTotalXP = awards.reduce(0) { $0 + $1.xpGranted }
                    debugInfo.dailyAwardCount = awards.count
                    
                    if let lastAward = awards.max(by: { $0.dateKey < $1.dateKey }) {
                        debugInfo.lastAwardDate = lastAward.dateKey
                    } else {
                        debugInfo.lastAwardDate = "None"
                    }
                    
                    // Check for today's award
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    let todayKey = formatter.string(from: Date())
                    debugInfo.todaysAwardGranted = awards.contains { $0.dateKey == todayKey }
                    debugInfo.todaysAwardStatus = debugInfo.todaysAwardGranted ? "✅ Granted" : "❌ Not granted"
                    
                    // Check sync status
                    debugInfo.isInSync = debugInfo.xpManagerTotalXP == debugInfo.swiftDataTotalXP
                    debugInfo.syncStatus = debugInfo.isInSync ? "✅ In sync" : "❌ Out of sync by \(abs(debugInfo.xpManagerTotalXP - debugInfo.swiftDataTotalXP)) XP"
                    
                    // Print detailed debug info
                    print("🔍 XP DEBUG DIAGNOSTIC:")
                    print("  Current userId: \(userId)")
                    print("  XPManager totalXP: \(debugInfo.xpManagerTotalXP)")
                    print("  SwiftData totalXP: \(debugInfo.swiftDataTotalXP)")
                    print("  DailyAward count: \(debugInfo.dailyAwardCount)")
                    print("  Last award date: \(debugInfo.lastAwardDate)")
                    print("  Today's award granted: \(debugInfo.todaysAwardGranted)")
                    print("  In sync: \(debugInfo.isInSync)")
                    
                    // Print all DailyAward records
                    print("  All DailyAward records:")
                    for (index, award) in awards.enumerated() {
                        print("    \(index + 1). dateKey: \(award.dateKey), xpGranted: \(award.xpGranted), userId: \(award.userId)")
                    }
                    
                } catch {
                    print("❌ Error fetching DailyAwards: \(error)")
                    debugInfo.syncStatus = "❌ Error fetching data"
                }
                
                isRunningDiagnostic = false
            }
        }
    }
    
    private func testAwardXP() {
        print("🧪 TEST: Force awarding 100 XP")
        // ✅ PHASE 4: debugForceAwardXP removed, use XPService.awardDailyCompletionIfEligible instead
        runDiagnostic()
    }
    
    private func testCompleteAllHabits() {
        print("🧪 TEST: Completing all habits programmatically")
        // This would need to be implemented to actually complete habits
        // For now, just show a message
        print("⚠️ TEST: Complete all habits - This would need to be implemented")
    }
    
    private func testIdempotency() {
        print("🧪 TEST: Testing idempotency - trying to award XP twice for today")
        
        Task {
            let today = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let todayKey = formatter.string(from: today)
            
            print("🧪 TEST: First award attempt for \(todayKey)")
            // This would need to be implemented to actually test the DailyAwardService
            // For now, just show what would happen
            print("⚠️ TEST: Idempotency test - This would need to be implemented")
            print("  - First call: Should award 100 XP")
            print("  - Second call: Should return false (no duplicate award)")
            print("  - Check that total XP only increased by 100, not 200")
        }
    }
    
    private func showTodaysAwards() {
        print("🧪 TEST: Showing today's DailyAward records")
        
        Task {
            await MainActor.run {
                do {
                    let userId = getCurrentUserId()
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    let todayKey = formatter.string(from: Date())
                    
                    let predicate = #Predicate<DailyAward> { award in
                        award.userId == userId && award.dateKey == todayKey
                    }
                    let request = FetchDescriptor<DailyAward>(predicate: predicate)
                    let awards = try modelContext.fetch(request)
                    
                    print("🧪 TEST: Found \(awards.count) DailyAward records for today (\(todayKey))")
                    for (index, award) in awards.enumerated() {
                        print("🧪 TEST:   Award \(index + 1): id=\(award.id), xpGranted=\(award.xpGranted), createdAt=\(award.createdAt)")
                    }
                    
                    // Test the unique constraint
                    let isUnique = DailyAward.validateUniqueConstraint(userId: userId, dateKey: todayKey, in: modelContext)
                    print("🧪 TEST: validateUniqueConstraint returns: \(isUnique)")
                    
                } catch {
                    print("❌ TEST: Error fetching today's awards: \(error)")
                }
            }
        }
    }
    
    private func showLevelAnalysis() {
        print("🧪 LEVEL ANALYSIS: Complete XP and Leveling Analysis")
        
        Task {
            await MainActor.run {
                let currentXP = xpManager.userProgress.totalXP
                let currentLevel = xpManager.userProgress.currentLevel
                let dailyXP = xpManager.userProgress.dailyXP
                
                print("🧪 LEVEL ANALYSIS: Current Status")
                print("  Current Level: \(currentLevel)")
                print("  Total XP: \(currentXP)")
                print("  Daily XP: \(dailyXP)")
                
                // Calculate level progression
                let levelBaseXP = 300 // Updated to new challenging progression
                let xpPerDay = 50 // Updated to new challenging progression
                
                print("\n🧪 LEVEL ANALYSIS: NEW CHALLENGING Level Progression Table")
                for level in 1...20 {
                    let xpNeeded = Int(pow(Double(level - 1), 2) * Double(levelBaseXP))
                    let daysNeeded = max(1, Int(ceil(Double(xpNeeded) / Double(xpPerDay))))
                    let status = level <= currentLevel ? "✅ ACHIEVED" : (level == currentLevel + 1 ? "🎯 NEXT" : "⏳ FUTURE")
                    print("  Level \(level): \(xpNeeded) XP (\(daysNeeded) days) \(status)")
                }
                
                // Calculate days to next level
                let nextLevel = currentLevel + 1
                let xpForNextLevel = Int(pow(Double(nextLevel - 1), 2) * Double(levelBaseXP))
                let xpNeeded = xpForNextLevel - currentXP
                let daysToNextLevel = max(0, Int(ceil(Double(xpNeeded) / Double(xpPerDay))))
                
                print("\n🧪 LEVEL ANALYSIS: Progress to Next Level")
                print("  Next Level: \(nextLevel)")
                print("  XP Needed: \(xpNeeded)")
                print("  Days Needed: \(daysToNextLevel)")
                
                // Calculate total XP from all awards
                do {
                    let userId = getCurrentUserId()
                    let predicate = #Predicate<DailyAward> { award in
                        award.userId == userId
                    }
                    let request = FetchDescriptor<DailyAward>(predicate: predicate)
                    let allAwards = try modelContext.fetch(request)
                    let totalAwardedXP = allAwards.reduce(0) { $0 + $1.xpGranted }
                    
                    print("\n🧪 LEVEL ANALYSIS: Historical Data")
                    print("  Total Awards: \(allAwards.count)")
                    print("  Total Awarded XP: \(totalAwardedXP)")
                    print("  Average XP per Award: \(allAwards.isEmpty ? 0 : totalAwardedXP / allAwards.count)")
                    
                    if !allAwards.isEmpty {
                        let firstAward = allAwards.min(by: { $0.createdAt < $1.createdAt })!
                        let daysSinceFirst = Calendar.current.dateComponents([.day], from: firstAward.createdAt, to: Date()).day ?? 0
                        let averageXPPerDay = daysSinceFirst > 0 ? Double(totalAwardedXP) / Double(daysSinceFirst) : 0
                        print("  Days Since First Award: \(daysSinceFirst)")
                        print("  Average XP per Day: \(String(format: "%.1f", averageXPPerDay))")
                    }
                } catch {
                    print("❌ LEVEL ANALYSIS: Error fetching historical data: \(error)")
                }
                
                print("\n🧪 LEVEL ANALYSIS: Assessment")
                if daysToNextLevel <= 1 {
                    print("  ⚡ Leveling is VERY FAST - consider increasing XP requirements")
                } else if daysToNextLevel <= 3 {
                    print("  🚀 Leveling is FAST - good for engagement")
                } else if daysToNextLevel <= 7 {
                    print("  ✅ Leveling is BALANCED - good pace")
                } else {
                    print("  🐌 Leveling is SLOW - consider decreasing XP requirements")
                }
            }
        }
    }
    
    private func investigateXPProgression() {
        print("🔍 XP INVESTIGATION: Comprehensive XP Analysis")
        
        Task {
            await MainActor.run {
                let currentXP = xpManager.userProgress.totalXP
                let currentLevel = xpManager.userProgress.currentLevel
                let dailyXP = xpManager.userProgress.dailyXP
                
                print("🔍 XP INVESTIGATION: Current Status")
                print("  Current Level: \(currentLevel)")
                print("  Total XP: \(currentXP)")
                print("  Daily XP: \(dailyXP)")
                
                // Check if level matches XP
                let expectedLevel = Int(sqrt(Double(currentXP) / 50.0)) + 1
                let levelMatches = currentLevel == expectedLevel
                print("  Expected Level (from XP): \(expectedLevel)")
                print("  Level Matches XP: \(levelMatches ? "✅ YES" : "❌ NO - BUG DETECTED!")")
                
                do {
                    let userId = getCurrentUserId()
                    let predicate = #Predicate<DailyAward> { award in
                        award.userId == userId
                    }
                    let request = FetchDescriptor<DailyAward>(predicate: predicate)
                    let allAwards = try modelContext.fetch(request)
                    
                    print("\n🔍 XP INVESTIGATION: Award History")
                    print("  Total Awards: \(allAwards.count)")
                    
                    if allAwards.isEmpty {
                        print("  ⚠️ NO AWARDS FOUND - This is suspicious if you have XP!")
                        print("  Possible causes:")
                        print("    - XP was awarded through debug methods")
                        print("    - XP was imported from old system")
                        print("    - XP was manually set")
                    } else {
                        // Sort awards by date
                        let sortedAwards = allAwards.sorted { $0.dateKey < $1.dateKey }
                        let totalAwardedXP = sortedAwards.reduce(0) { $0 + $1.xpGranted }
                        
                        print("  Total Awarded XP: \(totalAwardedXP)")
                        print("  XPManager Total XP: \(currentXP)")
                        print("  XP Sources Match: \(totalAwardedXP == currentXP ? "✅ YES" : "❌ NO - BUG DETECTED!")")
                        
                        print("\n🔍 XP INVESTIGATION: Daily Award Breakdown")
                        for (index, award) in sortedAwards.enumerated() {
                            print("  Award \(index + 1): \(award.dateKey) - \(award.xpGranted) XP - \(award.createdAt)")
                        }
                        
                        // Check for duplicate dates
                        let dateKeys = sortedAwards.map { $0.dateKey }
                        let uniqueDates = Set(dateKeys)
                        let hasDuplicates = dateKeys.count != uniqueDates.count
                        
                        print("\n🔍 XP INVESTIGATION: Duplicate Check")
                        print("  Unique Dates: \(uniqueDates.count)")
                        print("  Total Awards: \(dateKeys.count)")
                        print("  Has Duplicates: \(hasDuplicates ? "❌ YES - BUG DETECTED!" : "✅ NO")")
                        
                        if hasDuplicates {
                            let dateCounts = Dictionary(grouping: dateKeys) { $0 }
                            for (date, count) in dateCounts {
                                if count.count > 1 {
                                    print("    Duplicate date: \(date) appears \(count.count) times")
                                }
                            }
                        }
                        
                        // Calculate expected days of usage
                        let expectedDays = Int(ceil(Double(currentXP) / 100.0))
                        let actualDays = uniqueDates.count
                        
                        print("\n🔍 XP INVESTIGATION: Usage Analysis")
                        print("  Expected Days (XP/100): \(expectedDays)")
                        print("  Actual Award Days: \(actualDays)")
                        print("  Usage Matches XP: \(expectedDays == actualDays ? "✅ YES" : "❌ NO - BUG DETECTED!")")
                        
                        if !allAwards.isEmpty {
                            let firstAward = sortedAwards.first!
                            let lastAward = sortedAwards.last!
                            let daysSinceFirst = Calendar.current.dateComponents([.day], from: firstAward.createdAt, to: Date()).day ?? 0
                            let daysSinceLast = Calendar.current.dateComponents([.day], from: lastAward.createdAt, to: Date()).day ?? 0
                            
                            print("  First Award: \(firstAward.dateKey) (\(daysSinceFirst) days ago)")
                            print("  Last Award: \(lastAward.dateKey) (\(daysSinceLast) days ago)")
                            print("  Average XP per Day: \(String(format: "%.1f", Double(totalAwardedXP) / Double(max(1, daysSinceFirst))))")
                        }
                    }
                    
                    // Check for debug XP
                    print("\n🔍 XP INVESTIGATION: Debug XP Check")
                    let debugXP = xpManager.recentTransactions.filter { $0.description.contains("DEBUG") }
                    if !debugXP.isEmpty {
                        print("  ❌ DEBUG XP FOUND: \(debugXP.count) debug transactions")
                        for transaction in debugXP {
                            print("    Debug XP: \(transaction.amount) - \(transaction.description)")
                        }
                    } else {
                        print("  ✅ No debug XP found")
                    }
                    
                    // Check for non-standard XP amounts
                    let nonStandardAwards = allAwards.filter { $0.xpGranted != 100 }
                    if !nonStandardAwards.isEmpty {
                        print("  ❌ NON-STANDARD XP FOUND: \(nonStandardAwards.count) awards")
                        for award in nonStandardAwards {
                            print("    Non-standard: \(award.dateKey) - \(award.xpGranted) XP")
                        }
                    } else {
                        print("  ✅ All awards are standard 100 XP")
                    }
                    
                } catch {
                    print("❌ XP INVESTIGATION: Error fetching data: \(error)")
                }
                
                print("\n🔍 XP INVESTIGATION: Summary")
                if currentXP == 0 {
                    print("  📊 You have 0 XP - this is normal for new users")
                } else if currentXP < 100 {
                    print("  📊 You have \(currentXP) XP - less than one day's worth")
                    print("  🤔 This suggests partial completion or debug XP")
                } else {
                    let daysOfUsage = Int(ceil(Double(currentXP) / 100.0))
                    print("  📊 You have \(currentXP) XP - equivalent to \(daysOfUsage) days of completing all habits")
                    print("  🎯 This should put you at level \(expectedLevel)")
                    
                    if currentLevel != expectedLevel {
                        print("  ⚠️ LEVEL MISMATCH: You're level \(currentLevel) but should be level \(expectedLevel)")
                        print("  🔧 This indicates a bug in the level calculation or XP tracking")
                    }
                }
            }
        }
    }
    
    private func checkSyncStatus() {
        print("🧪 TEST: Checking sync status manually")
        runDiagnostic()
    }
    
    private func fixXPInflationBug() {
        print("🔧 FIXING XP INFLATION BUG")
        
        Task {
            await MainActor.run {
                let currentXP = xpManager.userProgress.totalXP
                let currentLevel = xpManager.userProgress.currentLevel
                
                print("🔧 BEFORE FIX:")
                print("  Current XP: \(currentXP)")
                print("  Current Level: \(currentLevel)")
                
                do {
                    let userId = getCurrentUserId()
                    let predicate = #Predicate<DailyAward> { award in
                        award.userId == userId
                    }
                    let request = FetchDescriptor<DailyAward>(predicate: predicate)
                    let allAwards = try modelContext.fetch(request)
                    
                    if allAwards.isEmpty {
                        print("🔧 NO AWARDS FOUND - This XP is from debug methods or old system!")
                        print("🔧 Resetting to 0 XP since no legitimate awards exist")
                        
                        xpManager.userProgress.totalXP = 0
                        xpManager.userProgress.dailyXP = 0
                        xpManager.userProgress.currentLevel = 1
                        
                        // Force level recalculation
                        xpManager.updateLevelFromXP()
                        
                        xpManager.saveUserProgress()
                        print("🔧 AFTER FIX: 0 XP, Level 1")
                        print("🔧 REMOVED \(currentXP) XP of debug/old system data!")
                    } else {
                        // Calculate correct XP from actual awards (excluding level-up bonuses)
                        let correctXP = allAwards.reduce(0) { total, award in
                            // Only count standard 50 XP awards, ignore any level-up bonuses
                            if award.xpGranted == 50 {
                                return total + award.xpGranted
                            } else {
                                print("🔧 Found non-standard award: \(award.dateKey) - \(award.xpGranted) XP (likely level-up bonus)")
                                return total // Ignore level-up bonuses
                            }
                        }
                        
                        // Calculate correct level from correct XP (using new challenging progression)
                        let correctLevel = Int(sqrt(Double(correctXP) / 300.0)) + 1
                        
                        // Manual verification of level calculation
                        print("🔧 LEVEL CALCULATION VERIFICATION:")
                        print("  correctXP: \(correctXP)")
                        print("  sqrt(correctXP / 300): \(sqrt(Double(correctXP) / 300.0))")
                        print("  Int(sqrt(correctXP / 300)): \(Int(sqrt(Double(correctXP) / 300.0)))")
                        print("  correctLevel: \(correctLevel)")
                        
                        // Show what level you should be at for different XP amounts
                        print("🔧 NEW CHALLENGING LEVEL REFERENCE:")
                        for xp in [0, 50, 100, 150, 300, 600, 900, 1200, 1800, 3000, 6000, 12000] {
                            let level = Int(sqrt(Double(xp) / 300.0)) + 1
                            let days = Int(ceil(Double(xp) / 50.0))
                            print("  \(xp) XP = Level \(level) (\(days) days)")
                        }
                        
                        print("\n🔧 NEW CHALLENGING PROGRESSION:")
                        print("  Level 2: 300 XP (6 days) - CHALLENGING!")
                        print("  Level 3: 900 XP (18 days) - CHALLENGING!")
                        print("  Level 4: 1,800 XP (36 days) - CHALLENGING!")
                        print("  Level 5: 3,000 XP (60 days) - CHALLENGING!")
                        print("  Level 10: 12,000 XP (240 days) - VERY CHALLENGING!")
                        print("  Level 20: 48,000 XP (960 days) - EXTREMELY CHALLENGING!")
                        
                        print("\n🔧 COMPARISON:")
                        print("  OLD: Level 4 in 4-5 days")
                        print("  NEW: Level 4 in 36 days (7x harder!)")
                        print("  OLD: Level 10 in 45 days")
                        print("  NEW: Level 10 in 240 days (5x harder!)")
                        
                        print("🔧 CALCULATED CORRECT VALUES:")
                        print("  Standard Awards: \(allAwards.filter { $0.xpGranted == 50 }.count)")
                        print("  Level-up Bonuses: \(allAwards.filter { $0.xpGranted != 50 }.count)")
                        print("  Correct XP: \(correctXP)")
                        print("  Correct Level: \(correctLevel)")
                        
                        // Apply the fix
                        print("🔧 APPLYING FIX:")
                        print("  Setting totalXP to: \(correctXP)")
                        print("  Setting dailyXP to: \(correctXP)")
                        print("  Setting currentLevel to: \(correctLevel)")
                        
                        xpManager.userProgress.totalXP = correctXP
                        xpManager.userProgress.dailyXP = correctXP
                        xpManager.userProgress.currentLevel = correctLevel
                        
                        // Force level recalculation to ensure it's correct
                        xpManager.updateLevelFromXP()
                        
                        print("🔧 AFTER FORCE RECALCULATION:")
                        print("  totalXP: \(xpManager.userProgress.totalXP)")
                        print("  currentLevel: \(xpManager.userProgress.currentLevel)")
                        
                        xpManager.saveUserProgress()
                        
                        print("🔧 AFTER FIX:")
                        print("  Fixed XP: \(correctXP)")
                        print("  Fixed Level: \(correctLevel)")
                        print("  XP Reduction: \(currentXP - correctXP)")
                        print("  Level Reduction: \(currentLevel - correctLevel)")
                        
                        // Show what was removed
                        let removedXP = currentXP - correctXP
                        if removedXP > 0 {
                            print("🔧 REMOVED \(removedXP) XP of level-up bonus inflation!")
                        }
                    }
                    
                } catch {
                    print("❌ FIX FAILED: Error fetching awards: \(error)")
                }
            }
        }
    }
    
    private func fixYesterdayXP() {
        print("🔧 FIXING YESTERDAY XP: Checking and awarding missing XP")
        
        Task {
            await MainActor.run {
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                let yesterdayKey = Habit.dateKey(for: yesterday)
                let userId = getCurrentUserId()
                
                print("🔧 Yesterday date: \(yesterdayKey)")
                print("🔧 User ID: \(userId)")
                
                // Check if all habits were completed yesterday
                let habits = HabitRepository.shared.habits
                var completedHabits = 0
                
                print("🔧 Checking habit completion status:")
                for habit in habits {
                    let isCompleted = habit.isCompleted(for: yesterday)
                    print("  Habit '\(habit.name)': \(isCompleted ? "✅ Completed" : "❌ Not completed")")
                    if isCompleted {
                        completedHabits += 1
                    }
                }
                
                let allCompleted = completedHabits == habits.count && !habits.isEmpty
                print("🔧 All habits completed yesterday: \(allCompleted) (\(completedHabits)/\(habits.count))")
                
                if allCompleted {
                    // Check if XP was already awarded
                    do {
                        let predicate = #Predicate<DailyAward> { award in
                            award.userId == userId && award.dateKey == yesterdayKey
                        }
                        let request = FetchDescriptor<DailyAward>(predicate: predicate)
                        let existingAwards = try modelContext.fetch(request)
                        
                        if existingAwards.isEmpty {
                            print("🔧 No XP awarded for yesterday - awarding now...")
                            
                            // Award XP through XPManager
                            let xpToAward = 50 // Standard daily completion XP
                            xpManager.updateXPFromDailyAward(xpGranted: xpToAward, dateKey: yesterdayKey)
                            
                            // Create DailyAward record
                            let award = DailyAward(
                                userId: userId,
                                dateKey: yesterdayKey,
                                xpGranted: xpToAward,
                                allHabitsCompleted: true
                            )
                            modelContext.insert(award)
                            try modelContext.save()
                            
                            print("🔧 ✅ XP awarded! New total: \(xpManager.userProgress.totalXP)")
                            print("🔧 ✅ DailyAward record created for \(yesterdayKey)")
                            
                        } else {
                            print("🔧 XP was already awarded for yesterday")
                            for award in existingAwards {
                                print("  Award: \(award.dateKey) - \(award.xpGranted) XP")
                            }
                        }
                        
                    } catch {
                        print("❌ Error checking/awarding XP: \(error)")
                    }
                } else {
                    print("🔧 ❌ Cannot award XP - not all habits were completed yesterday")
                    print("🔧 You need to complete all habits to receive daily XP")
                }
                
                // Refresh diagnostic
                runDiagnostic()
            }
        }
    }
    
    private func clearAllData() {
        print("🧪 TEST: Clearing all XP data")
        
        // Clear XPManager
        xpManager.userProgress.totalXP = 0
        xpManager.userProgress.dailyXP = 0
        xpManager.userProgress.currentLevel = 1
        xpManager.recentTransactions.removeAll()
        xpManager.saveUserProgress()
        xpManager.saveRecentTransactions()
        
        // Clear SwiftData DailyAwards
        Task {
            await MainActor.run {
                do {
                    let predicate = #Predicate<DailyAward> { _ in true }
                    let request = FetchDescriptor<DailyAward>(predicate: predicate)
                    let awards = try modelContext.fetch(request)
                    
                    for award in awards {
                        modelContext.delete(award)
                    }
                    
                    try modelContext.save()
                    print("✅ Cleared all DailyAward records")
                } catch {
                    print("❌ Error clearing DailyAwards: \(error)")
                }
                
                runDiagnostic()
            }
        }
    }
    
    private func getCurrentUserId() -> String {
        // Use consistent user ID across the system
        let userId = "debug_user_id"
        print("🎯 USER SCOPING: XPDebugPanel.getCurrentUserId() = \(userId) (debug mode)")
        return userId
    }
}

// MARK: - Debug Row
struct DebugRow: View {
    let label: String
    let value: String
    let isError: Bool
    
    init(label: String, value: String, isError: Bool = false) {
        self.label = label
        self.value = value
        self.isError = isError
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isError ? .red : .primary)
        }
    }
}

// MARK: - Debug Info Model
struct XPDebugInfo {
    var currentUserId: String = "Loading..."
    var xpManagerTotalXP: Int = 0
    var swiftDataTotalXP: Int = 0
    var isInSync: Bool = false
    var syncStatus: String = "Loading..."
    var dailyAwardCount: Int = 0
    var lastAwardDate: String = "Loading..."
    var todaysAwardGranted: Bool = false
    var todaysAwardStatus: String = "Loading..."
    var isAuthenticated: Bool = false
    var authStatus: String = "Loading..."
    var migrationCompleted: Bool = false
    var migrationStatus: String = "Loading..."
}

#Preview {
    XPDebugPanel()
        .padding()
        .background(Color.gray.opacity(0.1))
}

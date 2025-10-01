import SwiftUI
import SwiftData

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
                    .foregroundColor(.text01)
                
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
                    .foregroundColor(.text02)
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
                    DebugRow(label: "Auth issue:", value: "❌ Hardcoded userId - no auth integration", isError: true)
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
        .background(Color.surfaceDim)
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
                // Get current userId
                let userId = getCurrentUserId()
                debugInfo.currentUserId = userId
                
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
                    let todayKey = DateKey.key(for: Date())
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
        xpManager.debugForceAwardXP(100)
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
            // This would need to be implemented to actually test the DailyAwardService
            // For now, just show what would happen
            print("⚠️ TEST: Idempotency test - This would need to be implemented")
            print("  - First call: Should award 100 XP")
            print("  - Second call: Should return false (no duplicate award)")
            print("  - Check that total XP only increased by 100, not 200")
        }
    }
    
    private func checkSyncStatus() {
        print("🧪 TEST: Checking sync status manually")
        runDiagnostic()
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
        // This should match the userId used in DailyAwardService
        let userId = "current_user_id"
        print("🎯 USER SCOPING: XPDebugPanel.getCurrentUserId() = \(userId)")
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
                .foregroundColor(.text02)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isError ? .red : .text01)
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
}

#Preview {
    XPDebugPanel()
        .padding()
        .background(Color.gray.opacity(0.1))
}

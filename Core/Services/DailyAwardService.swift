import Foundation
import SwiftData
import Combine

/// Service for managing daily awards and streak/XP calculations
/// Swift actor ensures thread-safe operations and prevents race conditions
public actor DailyAwardService: ObservableObject {
    private let modelContext: ModelContext
    private let eventBus: EventBus
    
    // Constants for XP management
    private static let XP_PER_DAY = 100
    
    public init(modelContext: ModelContext, eventBus: EventBus = EventBus.shared) {
        self.modelContext = modelContext
        self.eventBus = eventBus
    }
    
    /// Idempotent method to grant daily award if all habits are completed
    /// Returns true if award was granted, false if already exists or not all habits completed
    public func grantIfAllComplete(date: Date, userId: String, callSite: String = #function) async -> Bool {
        let dateKey = DateKey.key(for: date)
        
        #if DEBUG
        let preXP = self.computeTotalXPFromLedger(userId: userId)
        print("🔍 TRACE [grantIfAllComplete]: callSite=\(callSite), user=\(userId), date=\(dateKey), preXP=\(preXP)")
        #endif
        
        // Check if all habits are completed for this date
        guard await areAllHabitsCompleted(dateKey: dateKey, userId: userId) else {
            #if DEBUG
            print("  ↳ Not all habits completed, no award granted")
            #endif
            return false
        }
        
        // Check if award already exists (idempotency)
        guard DailyAward.validateUniqueConstraint(userId: userId, dateKey: dateKey, in: modelContext) else {
            return false
        }
        
        // Create and insert award
        let award = DailyAward(userId: userId, dateKey: dateKey, xpGranted: Self.XP_PER_DAY)
        modelContext.insert(award)
        
        #if DEBUG
        // Capture pre-save state for runtime tripwire
        let preAwardCount = self.countAwardsForDay(userId: userId, dateKey: dateKey)
        let preSaveXP = self.computeTotalXPFromLedger(userId: userId)
        #endif
        
        do {
            #if DEBUG
            print("🔒 DailyAwardService.grantIfAllComplete: Executing save() [TRANSACTION START]")
            #endif
            
            try modelContext.save()
            
            #if DEBUG
            print("✅ DailyAwardService.grantIfAllComplete: save() completed [TRANSACTION END]")
            
            // Runtime tripwire: verify XP delta is exactly +XP_PER_DAY
            let postAwardCount = self.countAwardsForDay(userId: userId, dateKey: dateKey)
            let postSaveXP = self.computeTotalXPFromLedger(userId: userId)
            try self.assertXPDeltaValid(
                userId: userId,
                dateKey: dateKey,
                preXP: preSaveXP,
                postXP: postSaveXP,
                preAwards: preAwardCount,
                postAwards: postAwardCount,
                expectedDelta: Self.XP_PER_DAY
            )
            #endif
            
            // Update streak
            await self.updateStreak(userId: userId, dateKey: dateKey)
            
            // Emit event
            self.eventBus.publish(.dailyAwardGranted(dateKey: dateKey))
            
            // ✅ FIX: Update XPManager with the new XP
            await MainActor.run {
                print("🎯 DailyAwardService: Updating XPManager with \(Self.XP_PER_DAY) XP for \(dateKey)")
                XPManager.shared.updateXPFromDailyAward(xpGranted: Self.XP_PER_DAY, dateKey: dateKey)
                print("🎯 DailyAwardService: XPManager updated successfully")
            }
            
            #if DEBUG
            // Verify no extra XP was granted
            try? await self.assertNoExtraXP(userId: userId, dateKey: dateKey)
            
            let finalXP = self.computeTotalXPFromLedger(userId: userId)
            print("  ↳ ✅ Award granted: postXP=\(finalXP), delta=+\(finalXP - preXP)")
            #endif
            
            return true
        } catch {
            print("Failed to save daily award: \(error)")
            #if DEBUG
            print("  ↳ ❌ Save failed: \(error)")
            #endif
            return false
        }
    }
    
    /// Called when a habit is completed (legacy method for compatibility)
    /// Returns true if a daily award was granted
    public func onHabitCompleted(date: Date, userId: String) async -> Bool {
        return await grantIfAllComplete(date: date, userId: userId)
    }
    
    /// Idempotent method to revoke daily award if any habit is uncompleted
    /// Returns true if award was revoked, false if no award existed
    public func revokeIfAnyIncomplete(date: Date, userId: String, callSite: String = #function) async -> Bool {
        let dateKey = DateKey.key(for: date)
        
        #if DEBUG
        let preXP = self.computeTotalXPFromLedger(userId: userId)
        print("🔍 TRACE [revokeIfAnyIncomplete]: callSite=\(callSite), user=\(userId), date=\(dateKey), preXP=\(preXP)")
        #endif
        
        // Check if award exists for this date
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == dateKey
        }
        
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let existingAwards = (try? modelContext.fetch(request)) ?? []
        
        guard let award = existingAwards.first else {
            #if DEBUG
            print("  ↳ No award to revoke")
            #endif
            return false // No award to revoke
        }
        
        // Revoke award
        modelContext.delete(award)
        
        #if DEBUG
        // Capture pre-save state for runtime tripwire (after delete, before save)
        let preAwardCount = self.countAwardsForDay(userId: userId, dateKey: dateKey)
        let preSaveXP = self.computeTotalXPFromLedger(userId: userId)
        #endif
        
        do {
            #if DEBUG
            print("🔒 DailyAwardService.revokeIfAnyIncomplete: Executing save() [TRANSACTION START]")
            #endif
            
            try modelContext.save()
            
            #if DEBUG
            print("✅ DailyAwardService.revokeIfAnyIncomplete: save() completed [TRANSACTION END]")
            
            // Runtime tripwire: verify XP delta is exactly -XP_PER_DAY
            let postAwardCount = self.countAwardsForDay(userId: userId, dateKey: dateKey)
            let postSaveXP = self.computeTotalXPFromLedger(userId: userId)
            try self.assertXPDeltaValid(
                userId: userId,
                dateKey: dateKey,
                preXP: preSaveXP,
                postXP: postSaveXP,
                preAwards: preAwardCount,
                postAwards: postAwardCount,
                expectedDelta: -Self.XP_PER_DAY
            )
            #endif
            
            // Revert streak
            await self.revertStreak(userId: userId, dateKey: dateKey)
            
            // Emit event
            self.eventBus.publish(.dailyAwardRevoked(dateKey: dateKey))
            
            #if DEBUG
            let finalXP = self.computeTotalXPFromLedger(userId: userId)
            print("  ↳ ✅ Award revoked: postXP=\(finalXP), delta=\(finalXP - preXP)")
            #endif
            
            return true
        } catch {
            print("Failed to revoke daily award: \(error)")
            #if DEBUG
            print("  ↳ ❌ Save failed: \(error)")
            #endif
            return false
        }
    }
    
    /// Called when a habit is uncompleted (legacy method for compatibility)
    public func onHabitUncompleted(date: Date, userId: String) async {
        _ = await revokeIfAnyIncomplete(date: date, userId: userId)
    }
    
    // MARK: - Private Methods
    
    private func areAllHabitsCompleted(dateKey: String, userId: String) async -> Bool {
        // Get all habits for the user
        let predicate = #Predicate<HabitData> { habit in
            habit.userId == userId
        }
        
        let request = FetchDescriptor<HabitData>(predicate: predicate)
        let habits = (try? modelContext.fetch(request)) ?? []
        
        // Check if all habits are completed for the given date
        return habits.allSatisfy { habit in
            // Check if habit is completed for the given date by looking at completion history
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
            guard let targetDate = formatter.date(from: dateKey) else { return false }
            
            return habit.completionHistory.contains { (record: CompletionRecord) in
                Calendar.current.isDate(record.date, inSameDayAs: targetDate) && record.isCompleted
            }
        }
    }
    
    private func calculateDailyXP() async -> Int {
        // Calculate XP based on completed habits
        // Using the standardized XP_PER_DAY constant
        return Self.XP_PER_DAY
    }
    
    // MARK: - Debug Methods
    
    #if DEBUG
    /// Runtime tripwire: Assert XP delta is valid after save
    private func assertXPDeltaValid(
        userId: String,
        dateKey: String,
        preXP: Int,
        postXP: Int,
        preAwards: Int,
        postAwards: Int,
        expectedDelta: Int
    ) throws {
        let delta = postXP - preXP
        let awardDelta = postAwards - preAwards
        
        // Valid deltas: 0 (no-op), +XP_PER_DAY (grant), -XP_PER_DAY (revoke)
        let validDeltas: Set<Int> = [0, Self.XP_PER_DAY, -Self.XP_PER_DAY]
        
        if !validDeltas.contains(delta) {
            let awardsForDay = self.getAwardsForDay(userId: userId, dateKey: dateKey)
            preconditionFailure("""
                ❌ XP DELTA INVALID (DUPLICATE XP DETECTED)
                User: \(userId)
                Date: \(dateKey)
                Pre-XP: \(preXP)
                Post-XP: \(postXP)
                Delta: \(delta) (expected: \(expectedDelta))
                Pre-Awards: \(preAwards)
                Post-Awards: \(postAwards)
                Award-Delta: \(awardDelta)
                Awards for day: \(awardsForDay.map { "[\($0.dateKey): \($0.xpGranted) XP]" }.joined(separator: ", "))
                """)
        }
        
        // Verify delta matches expectation
        if delta != expectedDelta && delta != 0 {
            print("⚠️ XP delta mismatch: expected \(expectedDelta), got \(delta) (userId: \(userId), date: \(dateKey))")
        }
        
        print("✅ XP delta valid: \(delta) XP for user \(userId) on \(dateKey)")
    }
    
    /// Count awards for a specific day (within modelContext.perform)
    private func countAwardsForDay(userId: String, dateKey: String) -> Int {
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == dateKey
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awards = (try? modelContext.fetch(request)) ?? []
        return awards.count
    }
    
    /// Get awards for a specific day
    private func getAwardsForDay(userId: String, dateKey: String) -> [DailyAward] {
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == dateKey
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        return (try? modelContext.fetch(request)) ?? []
    }
    
    /// Recompute total XP from DailyAward ledger (source of truth)
    private func computeTotalXPFromLedger(userId: String) -> Int {
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awards = (try? modelContext.fetch(request)) ?? []
        return awards.reduce(0) { $0 + $1.xpGranted }
    }
    
    /// Debug method to verify no extra XP has been granted beyond the daily limit
    private func assertNoExtraXP(userId: String, dateKey: String) async throws {
        // Fetch all awards for this user and date
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == dateKey
        }
        
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awards = (try? modelContext.fetch(request)) ?? []
        
        // Verify only one award exists and XP is within limits
        assert(awards.count <= 1, "Multiple awards found for user \(userId) on \(dateKey)")
        if let award = awards.first {
            assert(award.xpGranted <= Self.XP_PER_DAY, "Award XP \(award.xpGranted) exceeds daily limit \(Self.XP_PER_DAY)")
        }
    }
    #endif
    
    private func updateStreak(userId: String, dateKey: String) async {
        // Update user streak based on consecutive daily awards
        // Implementation would depend on your user model
    }
    
    private func revertStreak(userId: String, dateKey: String) async {
        // Revert user streak when award is revoked
        // Implementation would depend on your user model
    }
}

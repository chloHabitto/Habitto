import Foundation
import OSLog
import SwiftData

/// Service for investigating and fixing DailyAward integrity issues
///
/// This service validates that DailyAward records match actual completion data:
/// - A DailyAward should only exist if ALL scheduled habits were completed on that date
/// - Invalid awards are identified and can be removed
@MainActor
class DailyAwardIntegrityService {
    
    // MARK: - Singleton
    
    static let shared = DailyAwardIntegrityService()
    
    private init() {}
    
    // MARK: - Dependencies
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "DailyAwardIntegrity")
    
    // MARK: - Investigation Results
    
    struct InvestigationResult {
        let totalAwards: Int
        let validAwards: Int
        let invalidAwards: [InvalidAward]
        let totalXPFromAwards: Int
        let validXP: Int
        let invalidXP: Int
        
        struct InvalidAward {
            let dateKey: String
            let xpGranted: Int
            let reason: String
            let scheduledHabitsCount: Int
            let completedHabitsCount: Int
            let missingHabits: [String]
        }
    }
    
    // MARK: - Investigation
    
    /// Investigate all DailyAwards and validate them against actual completion data
    ///
    /// This checks each DailyAward to ensure:
    /// 1. All scheduled habits for that date were actually completed
    /// 2. The award wasn't created incorrectly
    ///
    /// - Returns: InvestigationResult with details about valid and invalid awards
    func investigateDailyAwards(userId: String) async throws -> InvestigationResult {
        
        let modelContext = SwiftDataContainer.shared.modelContext
        
        // Fetch all DailyAwards for this user
        let awardPredicate = #Predicate<DailyAward> { award in
            award.userId == userId
        }
        let awardDescriptor = FetchDescriptor<DailyAward>(
            predicate: awardPredicate,
            sortBy: [SortDescriptor(\.dateKey, order: .forward)]
        )
        let allAwards = try modelContext.fetch(awardDescriptor)
        
        
        var validAwards: [DailyAward] = []
        var invalidAwards: [InvestigationResult.InvalidAward] = []
        var totalXP = 0
        var validXP = 0
        var invalidXP = 0
        
        // Validate each award
        for award in allAwards {
            totalXP += award.xpGranted
            
            // Parse dateKey to Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone.current
            guard let date = dateFormatter.date(from: award.dateKey) else {
                logger.warning("⚠️ Invalid dateKey format: \(award.dateKey)")
                invalidAwards.append(InvestigationResult.InvalidAward(
                    dateKey: award.dateKey,
                    xpGranted: award.xpGranted,
                    reason: "Invalid dateKey format",
                    scheduledHabitsCount: 0,
                    completedHabitsCount: 0,
                    missingHabits: []
                ))
                invalidXP += award.xpGranted
                continue
            }
            
            // Check if all scheduled habits were completed on this date
            let validationResult = await validateAward(award: award, date: date, userId: userId, modelContext: modelContext)
            
            if validationResult.isValid {
                validAwards.append(award)
                validXP += award.xpGranted
                logger.info("✅ Award for \(award.dateKey) is VALID (\(award.xpGranted) XP)")
            } else {
                invalidAwards.append(InvestigationResult.InvalidAward(
                    dateKey: award.dateKey,
                    xpGranted: award.xpGranted,
                    reason: validationResult.reason,
                    scheduledHabitsCount: validationResult.scheduledHabitsCount,
                    completedHabitsCount: validationResult.completedHabitsCount,
                    missingHabits: validationResult.missingHabits
                ))
                invalidXP += award.xpGranted
                logger.warning("❌ Award for \(award.dateKey) is INVALID: \(validationResult.reason)")
                logger.warning("   Scheduled: \(validationResult.scheduledHabitsCount), Completed: \(validationResult.completedHabitsCount)")
                if !validationResult.missingHabits.isEmpty {
                    logger.warning("   Missing habits: \(validationResult.missingHabits.joined(separator: ", "))")
                }
            }
        }
        
        let result = InvestigationResult(
            totalAwards: allAwards.count,
            validAwards: validAwards.count,
            invalidAwards: invalidAwards,
            totalXPFromAwards: totalXP,
            validXP: validXP,
            invalidXP: invalidXP
        )
        
        logger.info("✅ Investigation complete:")
        logger.info("   Total awards: \(result.totalAwards)")
        logger.info("   Valid awards: \(result.validAwards)")
        logger.info("   Invalid awards: \(result.invalidAwards.count)")
        logger.info("   Total XP: \(result.totalXPFromAwards)")
        logger.info("   Valid XP: \(result.validXP)")
        logger.info("   Invalid XP: \(result.invalidXP)")
        
        return result
    }
    
    // MARK: - Validation
    
    private struct ValidationResult {
        let isValid: Bool
        let reason: String
        let scheduledHabitsCount: Int
        let completedHabitsCount: Int
        let missingHabits: [String]
    }
    
    /// Validate a single DailyAward against actual completion data
    private func validateAward(
        award: DailyAward,
        date: Date,
        userId: String,
        modelContext: ModelContext
    ) async -> ValidationResult {
        // Get scheduled habits for this date
        let scheduledHabits = try? await HabitStore.shared.scheduledHabits(for: date)
        guard let scheduledHabits = scheduledHabits else {
            return ValidationResult(
                isValid: false,
                reason: "Failed to load scheduled habits",
                scheduledHabitsCount: 0,
                completedHabitsCount: 0,
                missingHabits: []
            )
        }
        
        // If no habits were scheduled, award should not exist
        if scheduledHabits.isEmpty {
            return ValidationResult(
                isValid: false,
                reason: "No habits scheduled for this date",
                scheduledHabitsCount: 0,
                completedHabitsCount: 0,
                missingHabits: []
            )
        }
        
        // ✅ SKIP FEATURE: Filter out skipped habits from award validation
        let activeHabits = scheduledHabits.filter { !$0.isSkipped(for: date) }
        let skippedCount = scheduledHabits.count - activeHabits.count
        
        if skippedCount > 0 {
            for habit in scheduledHabits where habit.isSkipped(for: date) {
                _ = habit.skipReason(for: date)?.shortLabel ?? "unknown"
            }
        }
        
        // If all habits were skipped, award is valid (user completed what they could)
        if activeHabits.isEmpty && !scheduledHabits.isEmpty {
            return ValidationResult(
                isValid: true,
                reason: "All habits were skipped - day counts as complete",
                scheduledHabitsCount: scheduledHabits.count,
                completedHabitsCount: 0,
                missingHabits: []
            )
        }
        
        // ✅ STREAK MODE: Use meetsStreakCriteria to validate awards (respects Streak Mode)
        _ = CompletionMode.current
        
        // Check each active (non-skipped) habit using meetsStreakCriteria (respects Streak Mode)
        var completedHabits: [Habit] = []
        var missingHabits: [String] = []
        
        for habit in activeHabits {
            let meetsCriteria = habit.meetsStreakCriteria(for: date)
            
            if meetsCriteria {
                completedHabits.append(habit)
            } else {
                missingHabits.append(habit.name)
            }
        }
        
        let allCompleted = missingHabits.isEmpty
        
        if allCompleted {
            return ValidationResult(
                isValid: true,
                reason: "All scheduled habits meet streak criteria",
                scheduledHabitsCount: scheduledHabits.count,
                completedHabitsCount: completedHabits.count,
                missingHabits: []
            )
        } else {
            return ValidationResult(
                isValid: false,
                reason: "Not all scheduled habits meet streak criteria",
                scheduledHabitsCount: scheduledHabits.count,
                completedHabitsCount: completedHabits.count,
                missingHabits: missingHabits
            )
        }
    }
    
    // MARK: - Cleanup
    
    /// Remove invalid DailyAwards and recalculate XP
    ///
    /// This will:
    /// 1. Investigate all awards
    /// 2. Delete invalid awards
    /// 3. Recalculate total XP from remaining valid awards
    /// 4. Update UserProgressData
    ///
    /// - Returns: Number of invalid awards removed
    func cleanupInvalidAwards(userId: String) async throws -> Int {
        
        // ✅ CRITICAL FIX: Verify habits exist before cleanup to prevent data loss
        // If no habits are found, skip cleanup (likely a timing/cache issue after sign-in)
        let modelContext = SwiftDataContainer.shared.modelContext
        let habitPredicate = #Predicate<HabitData> { habit in
            habit.userId == userId
        }
        let habitDescriptor = FetchDescriptor<HabitData>(predicate: habitPredicate)
        let habitsForUser = (try? modelContext.fetch(habitDescriptor)) ?? []
        
        if habitsForUser.isEmpty {
            logger.warning("⚠️ DailyAwardIntegrityService: Skipping cleanup - no habits found for userId '\(userId.isEmpty ? "guest" : userId.prefix(8))...' (possible timing issue)")
            print("⚠️ [DAILY_AWARD_INTEGRITY] Skipping cleanup - no habits found for user (possible timing/cache issue)")
            print("   This prevents data loss if cleanup runs before habits are fully loaded after sign-in")
            return 0
        }
        
        logger.info("✅ Found \(habitsForUser.count) habits for user - proceeding with cleanup")
        
        // Investigate first
        let investigation = try await investigateDailyAwards(userId: userId)
        
        if investigation.invalidAwards.isEmpty {
            logger.info("✅ No invalid awards found - nothing to clean up")
            return 0
        }
        
        
        // Delete invalid awards
        var removedCount = 0
        for invalidAward in investigation.invalidAwards {
            // Extract to local constant for #Predicate macro
            let invalidDateKey = invalidAward.dateKey
            let deletePredicate = #Predicate<DailyAward> { award in
                award.userId == userId && award.dateKey == invalidDateKey
            }
            let deleteDescriptor = FetchDescriptor<DailyAward>(predicate: deletePredicate)
            let awardsToDelete = (try? modelContext.fetch(deleteDescriptor)) ?? []
            
            for award in awardsToDelete {
                modelContext.delete(award)
                removedCount += 1
            }
        }
        
        // Save deletions
        try modelContext.save()
        logger.info("✅ Deleted \(removedCount) invalid awards")
        
        // Recalculate XP from remaining valid awards
        try await DailyAwardService.shared.repairIntegrity()
        
        logger.info("✅ Cleanup complete - Removed \(removedCount) invalid awards, XP recalculated")
        
        return removedCount
    }
    
    // MARK: - Diagnostic Logging
    
    /// Print detailed investigation report to console
    func printInvestigationReport(_ result: InvestigationResult) {
        print("")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 DAILY AWARD INTEGRITY INVESTIGATION REPORT")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")
        print("Total Awards: \(result.totalAwards)")
        print("Valid Awards: \(result.validAwards)")
        print("Invalid Awards: \(result.invalidAwards.count)")
        print("")
        print("Total XP from Awards: \(result.totalXPFromAwards)")
        print("Valid XP: \(result.validXP)")
        print("Invalid XP: \(result.invalidXP)")
        print("")
        
        if !result.invalidAwards.isEmpty {
            print("❌ INVALID AWARDS:")
            print("")
            for (index, invalid) in result.invalidAwards.enumerated() {
                print("  \(index + 1). Date: \(invalid.dateKey)")
                print("     XP: \(invalid.xpGranted)")
                print("     Reason: \(invalid.reason)")
                print("     Scheduled Habits: \(invalid.scheduledHabitsCount)")
                print("     Completed Habits: \(invalid.completedHabitsCount)")
                if !invalid.missingHabits.isEmpty {
                    print("     Missing: \(invalid.missingHabits.joined(separator: ", "))")
                }
                print("")
            }
        } else {
            print("✅ All awards are valid!")
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")
    }
}


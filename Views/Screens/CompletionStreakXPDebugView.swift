import SwiftUI

/// Debug screen showing completion counts, streak status, and XP totals
///
/// This view demonstrates the three core services:
/// - CompletionService: Today's completion counts
/// - StreakService: Current and longest streaks
/// - DailyAwardService: XP totals and level progression
struct CompletionStreakXPDebugView: View {
    // MARK: - Services
    
    @StateObject private var completionService = CompletionService.shared
    // TODO: Update to use new StreakService when integrated (no singleton pattern)
    // @StateObject private var streakService = StreakService.shared
    @StateObject private var xpService = DailyAwardService.shared
    @StateObject private var repository = FirestoreRepository.shared
    
    // MARK: - State
    
    @State private var selectedDate = Date()
    @State private var newHabitName = ""
    @State private var testHabitId = ""
    
    private let dateFormatter = LocalDateFormatter()
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Date Picker
                    datePickerSection
                    
                    // XP Section
                    xpSection
                    
                    // Completions Section
                    completionsSection
                    
                    // Streaks Section
                    streaksSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Integrity Check
                    integritySection
                }
                .padding()
            }
            .navigationTitle("Completion/Streak/XP Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Date Picker
    
    private var datePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Date")
                .font(.headline)
            
            HStack {
                Button {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.left")
                }
                
                Text(dateFormatter.dateToString(selectedDate))
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                
                Button {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Button("Today") {
                selectedDate = dateFormatter.todayDate()
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - XP Section
    
    private var xpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("XP & Level")
                .font(.headline)
            
            if let xpState = xpService.xpState {
                VStack(spacing: 8) {
                    // Total XP
                    HStack {
                        Text("Total XP:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(xpState.totalXP)")
                            .font(.title2.bold())
                            .foregroundColor(.green)
                    }
                    
                    // Level
                    HStack {
                        Text("Level:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(xpState.level)")
                            .font(.title2.bold())
                            .foregroundColor(.blue)
                    }
                    
                    // Progress in Current Level
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Level \(xpState.level) Progress:")
                                .foregroundColor(.secondary)
                            Spacer()
                            let progress = xpService.getLevelProgress()
                            Text("\(progress.current)/\(progress.needed)")
                                .font(.caption.bold())
                        }
                        
                        let progress = xpService.getLevelProgress()
                        ProgressView(value: Double(progress.current), total: Double(progress.needed))
                            .tint(.blue)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("No XP data")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Completions Section
    
    private var completionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Completions")
                .font(.headline)
            
            if completionService.todayCompletions.isEmpty {
                Text("No completions today")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(completionService.todayCompletions.keys.sorted()), id: \.self) { habitId in
                        HStack {
                            Text(habitId.prefix(8))
                                .font(.system(.caption, design: .monospaced))
                            Spacer()
                            Text("\(completionService.todayCompletions[habitId] ?? 0)")
                                .font(.title3.bold())
                                .foregroundColor(.green)
                            Text("times")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Streaks Section
    
    private var streaksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streaks")
                .font(.headline)
            
            // TODO: Update to use new StreakService API
            /*
            if streakService.streaks.isEmpty {
                Text("No streaks yet")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(streakService.streaks.values.sorted(by: { $0.current > $1.current })), id: \.habitId) { streak in
            */
            // Placeholder for new StreakService integration
            Text("Streak display temporarily disabled - awaiting new StreakService integration")
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            VStack(spacing: 8) {
                // Create Test Habit
                HStack {
                    TextField("Habit name", text: $newHabitName)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Create") {
                        Task {
                            do {
                                testHabitId = try await repository.createHabit(
                                    name: newHabitName.isEmpty ? "Test Habit" : newHabitName,
                                    color: "green500",
                                    type: "formation"
                                )
                                newHabitName = ""
                                print("✅ Created habit: \(testHabitId)")
                            } catch {
                                print("❌ Failed to create habit: \(error)")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(repository.habits.count >= 5)
                }
                
                Divider()
                
                // Complete Habit
                Button("Complete Habit (if exists)") {
                    Task {
                        let habitId = testHabitId.isEmpty ? repository.habits.first?.id ?? "none" : testHabitId
                        guard habitId != "none" else { return }
                        
                        do {
                            let count = try await completionService.markComplete(habitId: habitId, at: selectedDate)
                            // TODO: Update to use new StreakService API
                            // try await streakService.calculateStreak(habitId: habitId, date: selectedDate, isComplete: true)
                            try await xpService.awardHabitCompletionXP(habitId: habitId, habitName: "Test", on: selectedDate)
                            print("✅ Completed habit, count: \(count)")
                        } catch {
                            print("❌ Failed to complete: \(error)")
                        }
                    }
                }
                .buttonStyle(.bordered)
                .tint(.green)
                .disabled(repository.habits.isEmpty)
                
                // Award Bonus XP
                Button("Award Daily Bonus (50 XP)") {
                    Task {
                        do {
                            try await xpService.awardDailyCompletionBonus(on: selectedDate)
                            print("✅ Awarded daily bonus")
                        } catch {
                            print("❌ Failed to award: \(error)")
                        }
                    }
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Integrity Section
    
    private var integritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("XP Integrity")
                .font(.headline)
            
            VStack(spacing: 8) {
                Button("Verify Integrity") {
                    Task {
                        do {
                            let isValid = try await xpService.verifyIntegrity()
                            print(isValid ? "✅ Integrity valid" : "⚠️ Integrity mismatch")
                        } catch {
                            print("❌ Integrity check failed: \(error)")
                        }
                    }
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                
                Button("Repair Integrity") {
                    Task {
                        do {
                            try await xpService.repairIntegrity()
                            print("✅ Integrity repaired")
                        } catch {
                            print("❌ Repair failed: \(error)")
                        }
                    }
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                
                Button("Check & Auto-Repair") {
                    Task {
                        do {
                            let success = try await xpService.checkAndRepairIntegrity()
                            print(success ? "✅ Integrity OK" : "⚠️ Repaired")
                        } catch {
                            print("❌ Failed: \(error)")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

#Preview {
    CompletionStreakXPDebugView()
}


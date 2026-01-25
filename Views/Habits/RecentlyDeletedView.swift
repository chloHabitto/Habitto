import SwiftUI
import SwiftData

// MARK: - RecentlyDeletedView

/// View that shows soft-deleted habits with restore and permanent delete options
struct RecentlyDeletedView: View {
  // MARK: Internal
  
  @Environment(\.dismiss) private var dismiss
  @State private var softDeletedHabits: [Habit] = []
  @State private var softDeletedHabitData: [HabitData] = []
  @State private var isLoading = true
  @State private var errorMessage: String?
  
  var body: some View {
    NavigationView {
      ZStack {
        if isLoading {
          // Loading state
          ProgressView("habits.recentlyDeleted.loading".localized)
            .progressViewStyle(.circular)
        } else if let error = errorMessage {
          // Error state
          VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
              .font(.system(size: 48))
              .foregroundColor(.orange)
            
            Text("habits.recentlyDeleted.error".localized)
              .font(.appHeadlineSmall)
            
            Text(error)
              .font(.appBodyLarge)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 32)
            
            Button("habits.recentlyDeleted.tryAgain".localized) {
              Task {
                await loadSoftDeletedHabits()
              }
            }
            .buttonStyle(.bordered)
          }
        } else if softDeletedHabits.isEmpty {
          // Empty state
          VStack(spacing: 16) {
            Image(systemName: "trash.slash")
              .font(.system(size: 48))
              .foregroundColor(.secondary)
            
            Text("habits.recentlyDeleted.noDeleted".localized)
              .font(.appHeadlineSmall)
            
            Text("habits.recentlyDeleted.description".localized)
              .font(.appBodyLarge)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 32)
          }
        } else {
          // Habit list
          List {
            Section {
              // Warning banner
              HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                  .font(.system(size: 20))
                  .foregroundColor(.orange)
                
                Text("habits.recentlyDeleted.warning".localized)
                  .font(.appCaptionMedium)
                  .foregroundColor(.secondary)
              }
              .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
              .listRowBackground(Color.orange.opacity(0.1))
            }
            
            Section {
              ForEach(Array(zip(softDeletedHabits, softDeletedHabitData)), id: \.0.id) { habit, habitData in
                RecentlyDeletedRowWithData(
                  habit: habit,
                  habitData: habitData,
                  onRestore: {
                    Task {
                      await restoreHabit(habit)
                    }
                  },
                  onDeleteForever: {
                    Task {
                      await permanentlyDelete(habit)
                    }
                  }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
              }
            }
          }
          .listStyle(.plain)
        }
      }
      .navigationTitle("habits.recentlyDeleted.title".localized)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("common.done".localized) {
            dismiss()
          }
        }
      }
    }
    .onAppear {
      Task {
        await loadSoftDeletedHabits()
      }
    }
  }
  
  // MARK: Private
  
  /// Load soft-deleted habits from repository
  private func loadSoftDeletedHabits() async {
    isLoading = true
    errorMessage = nil
    
    do {
      let habits = try await HabitRepository.shared.loadSoftDeletedHabits()
      
      // Also fetch HabitData to get deletedAt timestamps
      await MainActor.run {
        let modelContext = SwiftDataContainer.shared.modelContext
        
        // Query soft-deleted HabitData within 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<HabitData>(
          predicate: #Predicate { habitData in
            habitData.deletedAt != nil && habitData.deletedAt! > thirtyDaysAgo
          },
          sortBy: [SortDescriptor(\.deletedAt, order: .reverse)])
        
        if let habitDataList = try? modelContext.fetch(descriptor) {
          self.softDeletedHabitData = habitDataList
        }
      }
      
      await MainActor.run {
        self.softDeletedHabits = habits
        self.isLoading = false
      }
      
      print("♻️ [RECENTLY_DELETED] Loaded \(habits.count) soft-deleted habits")
      
    } catch {
      await MainActor.run {
        self.errorMessage = error.localizedDescription
        self.isLoading = false
      }
      print("❌ [RECENTLY_DELETED] Failed to load soft-deleted habits: \(error.localizedDescription)")
    }
  }
  
  /// Restore a soft-deleted habit
  private func restoreHabit(_ habit: Habit) async {
    print("♻️ [RESTORE] RecentlyDeletedView.restoreHabit() - START for habit: \(habit.name)")
    
    do {
      try await HabitRepository.shared.restoreSoftDeletedHabit(habit)
      
      // Remove from local list
      await MainActor.run {
        softDeletedHabits.removeAll { $0.id == habit.id }
        softDeletedHabitData.removeAll { $0.id == habit.id }
      }
      
      print("♻️ [RESTORE] Habit restored from Recently Deleted: \(habit.name)")
      
    } catch {
      await MainActor.run {
        errorMessage = "Failed to restore habit: \(error.localizedDescription)"
      }
      print("❌ [RESTORE] Failed to restore habit: \(error.localizedDescription)")
    }
  }
  
  /// Permanently delete a habit (hard delete)
  private func permanentlyDelete(_ habit: Habit) async {
    print("🗑️ [HARD_DELETE] RecentlyDeletedView.permanentlyDelete() - START for habit: \(habit.name)")
    
    do {
      try await HabitRepository.shared.permanentlyDeleteHabit(habit)
      
      // Remove from local list
      await MainActor.run {
        softDeletedHabits.removeAll { $0.id == habit.id }
        softDeletedHabitData.removeAll { $0.id == habit.id }
      }
      
      print("🗑️ [HARD_DELETE] Habit permanently deleted: \(habit.name)")
      
    } catch {
      await MainActor.run {
        errorMessage = "Failed to delete habit: \(error.localizedDescription)"
      }
      print("❌ [HARD_DELETE] Failed to permanently delete habit: \(error.localizedDescription)")
    }
  }
}

// MARK: - RecentlyDeletedRowWithData

/// Extended row that includes HabitData for accurate deletedAt timestamp
private struct RecentlyDeletedRowWithData: View {
  let habit: Habit
  let habitData: HabitData
  let onRestore: () -> Void
  let onDeleteForever: () -> Void
  
  @State private var showingDeleteConfirmation = false
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Habit info
      HStack(spacing: 12) {
        // Icon
        Text(habit.icon)
          .font(.system(size: 32))
        
        VStack(alignment: .leading, spacing: 4) {
          // Name
          Text(habit.name)
            .font(.appBodyLargeEmphasised)
            .foregroundColor(.primary)
          
          // Deletion info
          HStack(spacing: 8) {
            if let deletedAt = habitData.deletedAt {
              Text(String(format: "habits.recentlyDeleted.deletedDaysAgo".localized, daysAgo(from: deletedAt)))
                .font(.appCaptionMedium)
                .foregroundColor(.secondary)
              
              Text("•")
                .font(.appCaptionMedium)
                .foregroundColor(.secondary)
              
              let daysLeft = daysLeftToRecover(from: deletedAt)
              Text(String(format: "habits.recentlyDeleted.daysLeftToRecover".localized, daysLeft))
                .font(.appCaptionMedium)
                .foregroundColor(daysLeft <= 7 ? .orange : .secondary)
            }
          }
        }
        
        Spacer()
      }
      
      // Action buttons
      HStack(spacing: 12) {
        // Restore button (primary action)
        Button(action: onRestore) {
          HStack(spacing: 6) {
            Image(systemName: "arrow.uturn.backward")
              .font(.system(size: 14, weight: .semibold))
            Text("habits.recentlyDeleted.restore".localized)
              .font(.appButtonText2)
          }
          .foregroundColor(.white)
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(Color.accentColor)
          .cornerRadius(8)
        }
        
        // Delete Forever button (destructive action)
        Button(action: {
          showingDeleteConfirmation = true
        }) {
          HStack(spacing: 6) {
            Image(systemName: "trash")
              .font(.system(size: 14, weight: .semibold))
            Text("habits.recentlyDeleted.deleteForever".localized)
              .font(.appButtonText2)
          }
          .foregroundColor(.red)
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(Color.red.opacity(0.1))
          .cornerRadius(8)
        }
        
        Spacer()
      }
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
    .background(Color(.systemGray6))
    .cornerRadius(12)
    .alert("habits.recentlyDeleted.deleteForever".localized, isPresented: $showingDeleteConfirmation) {
      Button("common.cancel".localized, role: .cancel) { }
      Button("habits.recentlyDeleted.deleteForever".localized, role: .destructive) {
        onDeleteForever()
      }
    } message: {
      Text(String(format: "habits.recentlyDeleted.deleteForeverConfirm".localized, habit.name))
    }
  }
  
  /// Calculate days ago from a date
  private func daysAgo(from date: Date) -> Int {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.day], from: date, to: Date())
    return components.day ?? 0
  }
  
  /// Calculate days left to recover (30 days total)
  private func daysLeftToRecover(from deletedAt: Date) -> Int {
    let calendar = Calendar.current
    let thirtyDaysLater = calendar.date(byAdding: .day, value: 30, to: deletedAt) ?? deletedAt
    let components = calendar.dateComponents([.day], from: Date(), to: thirtyDaysLater)
    return max(0, components.day ?? 0)
  }
}

// MARK: - Preview

#Preview {
  RecentlyDeletedView()
}

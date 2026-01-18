import SwiftUI

// MARK: - RecentlyDeletedRow

/// A row component for displaying a soft-deleted habit with restore and delete forever actions
struct RecentlyDeletedRow: View {
  // MARK: Lifecycle
  
  init(
    habit: Habit,
    onRestore: @escaping () -> Void,
    onDeleteForever: @escaping () -> Void
  ) {
    self.habit = habit
    self.onRestore = onRestore
    self.onDeleteForever = onDeleteForever
  }
  
  // MARK: Internal
  
  let habit: Habit
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
            if let deletedAt = deletedDate {
              Text("Deleted \(daysAgo(from: deletedAt)) days ago")
                .font(.appCaptionMedium)
                .foregroundColor(.secondary)
              
              Text("•")
                .font(.appCaptionMedium)
                .foregroundColor(.secondary)
              
              let daysLeft = daysLeftToRecover(from: deletedAt)
              Text("\(daysLeft) days left to recover")
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
            Text("Restore")
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
            Text("Delete Forever")
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
    .alert("Delete Forever", isPresented: $showingDeleteConfirmation) {
      Button("Cancel", role: .cancel) { }
      Button("Delete Forever", role: .destructive) {
        onDeleteForever()
      }
    } message: {
      Text("Are you sure you want to permanently delete \"\(habit.name)\"? This action cannot be undone.")
    }
  }
  
  // MARK: Private
  
  /// Calculate the deleted date from the habit (this would come from HabitData.deletedAt in the real implementation)
  /// For now, we'll use a placeholder since Habit model doesn't have deletedAt
  private var deletedDate: Date? {
    // In the real implementation, this would come from fetching HabitData by ID
    // For now, return a date 5 days ago as a placeholder
    Calendar.current.date(byAdding: .day, value: -5, to: Date())
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
  VStack(spacing: 16) {
    RecentlyDeletedRow(
      habit: Habit(
        name: "Morning Yoga",
        description: "Daily yoga practice",
        icon: "🧘",
        color: .blue,
        habitType: .formation,
        schedule: "Everyday",
        goal: "1 time",
        reminder: "No reminder",
        startDate: Date(),
        endDate: nil
      ),
      onRestore: {
        print("Restore tapped")
      },
      onDeleteForever: {
        print("Delete forever tapped")
      }
    )
    .padding(.horizontal, 16)
    
    RecentlyDeletedRow(
      habit: Habit(
        name: "Reading",
        description: "Read for 30 minutes",
        icon: "📚",
        color: .green,
        habitType: .formation,
        schedule: "Everyday",
        goal: "30 minutes",
        reminder: "No reminder",
        startDate: Date(),
        endDate: nil
      ),
      onRestore: {
        print("Restore tapped")
      },
      onDeleteForever: {
        print("Delete forever tapped")
      }
    )
    .padding(.horizontal, 16)
  }
  .padding(.vertical, 16)
}

import SwiftUI
import SwiftData
import Foundation

/// Debug view for checking migration completion status
struct MigrationStatusDebugView: View {
  @State private var migrationStatuses: [MigrationCompletionStatus] = []
  @State private var isLoading = true
  
  var body: some View {
    NavigationStack {
      List {
        if isLoading {
          ProgressView("Loading migration status...")
        } else {
          // Migration Status Section
          Section("Migration Status") {
            ForEach(migrationStatuses) { status in
              HStack {
                Image(systemName: status.isCompleted ? "checkmark.circle.fill" : "circle")
                  .foregroundColor(status.isCompleted ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                  Text(status.name)
                    .font(.headline)
                  
                  Text(status.key)
                    .font(.caption)
                    .foregroundColor(.secondary)
                  
                  if let date = status.completedDate {
                    Text("Completed: \(date, style: .relative)")
                      .font(.caption2)
                      .foregroundColor(.secondary)
                  }
                }
                
                Spacer()
                
                Text(status.isCompleted ? "✅" : "⏳")
                  .font(.title2)
              }
              .padding(.vertical, 4)
            }
          }
          
          // Data Counts Section
          Section("Data Verification") {
            HStack {
              Text("Progress Events")
              Spacer()
              Text("\(progressEventCount)")
                .foregroundColor(.secondary)
            }
            
            HStack {
              Text("Completion Records")
              Spacer()
              Text("\(completionRecordCount)")
                .foregroundColor(.secondary)
            }
            
            HStack {
              Text("Daily Awards")
              Spacer()
              Text("\(dailyAwardCount)")
                .foregroundColor(.secondary)
            }
            
            Button("Refresh Counts") {
              Task {
                await refreshDataCounts()
              }
            }
            .foregroundColor(.blue)
          }
          
          // Actions Section
          Section("Actions") {
            Button("Refresh Status") {
              Task {
                await loadMigrationStatuses()
              }
            }
            .foregroundColor(.blue)
          }
        }
      }
      .navigationTitle("Migration Status")
      .navigationBarTitleDisplayMode(.inline)
      .task {
        await loadMigrationStatuses()
        await refreshDataCounts()
      }
    }
  }
  
  // MARK: - Private
  
  @State private var progressEventCount = 0
  @State private var completionRecordCount = 0
  @State private var dailyAwardCount = 0
  
  private func loadMigrationStatuses() async {
    isLoading = true
    defer { isLoading = false }
    
    var statuses: [MigrationCompletionStatus] = []
    
    // Check GuestToAuthMigration (dynamic key based on userId)
    if let userId = AuthenticationManager.shared.currentUser?.uid {
      let guestKey = "GuestToAuthMigration_\(userId)"
      let isCompleted = UserDefaults.standard.bool(forKey: guestKey)
      statuses.append(MigrationCompletionStatus(
        name: "Guest to Auth Migration",
        key: guestKey,
        isCompleted: isCompleted
      ))
    }
    
    // Check CompletionStatusMigration
    let statusKey = "completion_status_migration_completed"
    statuses.append(MigrationCompletionStatus(
      name: "Completion Status Migration",
      key: statusKey,
      isCompleted: UserDefaults.standard.bool(forKey: statusKey)
    ))
    
    // Check MigrateCompletionsToEvents
    let eventsKey = "completions_to_events_migration_completed"
    statuses.append(MigrationCompletionStatus(
      name: "Completions to Events Migration",
      key: eventsKey,
      isCompleted: UserDefaults.standard.bool(forKey: eventsKey)
    ))
    
    // Check XPDataMigration
    let xpKey = "XPDataMigration_Completed"
    statuses.append(MigrationCompletionStatus(
      name: "XP Data Migration",
      key: xpKey,
      isCompleted: UserDefaults.standard.bool(forKey: xpKey)
    ))
    
    await MainActor.run {
      self.migrationStatuses = statuses
    }
  }
  
  private func refreshDataCounts() async {
    await MainActor.run {
      let modelContext = SwiftDataContainer.shared.modelContext
      
      // Count ProgressEvents
      let eventDescriptor = FetchDescriptor<ProgressEvent>()
      if let events = try? modelContext.fetch(eventDescriptor) {
        progressEventCount = events.count
      }
      
      // Count CompletionRecords
      let completionDescriptor = FetchDescriptor<CompletionRecord>()
      if let completions = try? modelContext.fetch(completionDescriptor) {
        completionRecordCount = completions.count
      }
      
      // Count DailyAwards
      let awardDescriptor = FetchDescriptor<DailyAward>()
      if let awards = try? modelContext.fetch(awardDescriptor) {
        dailyAwardCount = awards.count
      }
    }
  }
}

// MARK: - MigrationCompletionStatus

struct MigrationCompletionStatus: Identifiable {
  let id = UUID()
  let name: String
  let key: String
  let isCompleted: Bool
  let completedDate: Date? = nil // Could be enhanced to track dates
}

// MARK: - Preview

#Preview {
  MigrationStatusDebugView()
}

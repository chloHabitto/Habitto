import SwiftUI

/// View for managing guest data migration when users create accounts
struct GuestDataMigrationView: View {
  // MARK: Internal

  // MARK: - Body

  var body: some View {
    VStack(spacing: 20) {
      // Header
      VStack(spacing: 8) {
        Image(systemName: "person.badge.plus")
          .font(.system(size: 50))
          .foregroundColor(.blue)

        Text("Welcome to Your Account!")
          .font(.title2)
          .fontWeight(.bold)

        Text("We found some data you created while using the app. Would you like to keep it?")
          .font(.body)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(.top, 20)

      // Multi-Device Warning Banner
      if migrationManager.hasGuestData() {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.orange)
            .font(.title3)

          VStack(alignment: .leading, spacing: 4) {
            Text("Important: Single Device Only")
              .font(.headline)
              .foregroundColor(.primary)

            Text(
              "Guest mode data is stored only on this device. If you've used Habitto on multiple devices, only this device's data will be migrated to your new account.")
              .font(.caption)
              .foregroundColor(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.orange.opacity(0.3), lineWidth: 1))
      }

      // Migration Preview
      if migrationManager.hasGuestData() {
        VStack(spacing: 16) {
          // Data Summary
          VStack(spacing: 12) {
            HStack {
              Image(systemName: "list.bullet")
                .foregroundColor(.blue)
              Text("Habits Created")
              Spacer()
              Text("\(migrationManager.getGuestDataPreview()?.habitCount ?? 0)")
                .fontWeight(.semibold)
            }

            HStack {
              Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.green)
              Text("Backups Available")
              Spacer()
              Text("\(migrationManager.getGuestDataPreview()?.backupCount ?? 0)")
                .fontWeight(.semibold)
            }
          }
          .padding()
          .background(Color(.systemGray6))
          .cornerRadius(12)

          // Action Buttons
          VStack(spacing: 12) {
            // Keep Data Button
            Button(action: {
              showingMultiDeviceWarning = true
            }) {
              HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Keep My Data")
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.blue)
              .foregroundColor(.white)
              .cornerRadius(12)
            }
            .disabled(migrationManager.isMigrating)

            // Start Fresh Button
            Button(action: {
              Task {
                await startFresh()
              }
            }) {
              HStack {
                Image(systemName: "trash.circle")
                Text("Start Fresh")
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color(.systemGray5))
              .foregroundColor(.primary)
              .cornerRadius(12)
            }
            .disabled(migrationManager.isMigrating)
          }
        }
      } else {
        // No guest data found
        VStack(spacing: 16) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 40))
            .foregroundColor(.green)

          Text("No Data Found")
            .font(.headline)

          Text("You can start creating habits right away!")
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
      }

      // Migration Progress
      if migrationManager.isMigrating {
        VStack(spacing: 12) {
          ProgressView(value: migrationManager.migrationProgress)
            .progressViewStyle(LinearProgressViewStyle())

          Text(migrationManager.migrationStatus)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
      }

      Spacer()
    }
    .padding()
    .navigationTitle("Data Migration")
    .navigationBarTitleDisplayMode(.inline)
    .alert("Migration Error", isPresented: $showingError) {
      Button("OK") { }
    } message: {
      Text(migrationError ?? "An unknown error occurred")
    }
    .alert("Migrate This Device's Data?", isPresented: $showingMultiDeviceWarning) {
      Button("Cancel", role: .cancel) { }
      Button("Keep This Device's Data", role: .destructive) {
        Task {
          await migrateGuestData()
        }
      }
    } message: {
      Text(
        "You're using Habitto in guest mode on this device.\n\nIf you've used guest mode on other devices, their data CANNOT be merged. Only this device's \(migrationManager.getGuestDataPreview()?.habitCount ?? 0) habit(s) will be migrated to your new account.\n\nData from other devices will need to be manually recreated after signing in.")
    }
  }

  // MARK: Private

  @StateObject private var migrationManager = GuestDataMigration()
  @State private var showingMigrationPreview = false
  @State private var migrationError: String?
  @State private var showingError = false
  @State private var showingMultiDeviceWarning = false

  /// Repository for handling migration completion
  private let habitRepository = HabitRepository.shared

  private func migrateGuestData() async {
    do {
      try await migrationManager.migrateGuestData()
      // Migration completed successfully
      habitRepository.handleMigrationCompleted()
    } catch {
      migrationError = error.localizedDescription
      showingError = true
    }
  }

  private func startFresh() async {
    // Clear guest data without migrating
    // This will allow the user to start with a clean slate
    // The guest data will remain in storage but won't be migrated
    print("🔄 GuestDataMigrationView: User chose to start fresh")
    habitRepository.handleStartFresh()
  }
}

// MARK: - Preview

#Preview {
  NavigationView {
    GuestDataMigrationView()
  }
}

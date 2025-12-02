import SwiftUI

/// View for managing guest data migration when users create accounts
struct GuestDataMigrationView: View {
  // MARK: Internal

  // MARK: - Body

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        // Header
        VStack(spacing: 16) {
          Image(systemName: "person.badge.plus")
            .font(.system(size: 64))
            .foregroundColor(.primary)

          Text("Welcome to Your Account!")
            .font(.appHeadlineMediumEmphasised)
            .foregroundColor(.text01)
            .multilineTextAlignment(.center)

          Text("We found some data you created while using the app. Would you like to keep it?")
            .font(.appBodyMedium)
            .foregroundColor(.text03)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
        }
        .padding(.top, 40)

        // Multi-Device Warning Banner
        if migrationManager.hasGuestData() {
          HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundColor(.warning)
              .font(.system(size: 20))
              .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
              Text("Important: Single Device Only")
                .font(.appTitleMediumEmphasised)
                .foregroundColor(.text01)

              Text(
                "Guest mode data is stored only on this device. If you've used Habitto on multiple devices, only this device's data will be migrated to your new account.")
                .font(.appBodySmall)
                .foregroundColor(.text03)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(16)
          .background(Color.errorBackground)
          .cornerRadius(16)
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(Color.warning.opacity(0.3), lineWidth: 1))
          .padding(.horizontal, 20)
        }

        // Migration Preview
        if migrationManager.hasGuestData() {
          VStack(spacing: 20) {
            // Data Summary Card
            VStack(spacing: 16) {
              HStack(spacing: 12) {
                Image(systemName: "list.bullet")
                  .font(.system(size: 20))
                  .foregroundColor(.primary)
                  .frame(width: 24)
                
                Text("Habits Created")
                  .font(.appBodyLarge)
                  .foregroundColor(.text01)
                
                Spacer()
                
                Text("\(migrationManager.getGuestDataPreview()?.habitCount ?? 0)")
                  .font(.appBodyLargeEmphasised)
                  .foregroundColor(.text01)
              }

              Divider()
                .background(Color.outline2)

              HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                  .font(.system(size: 20))
                  .foregroundColor(.success)
                  .frame(width: 24)
                
                Text("Backups Available")
                  .font(.appBodyLarge)
                  .foregroundColor(.text01)
                
                Spacer()
                
                Text("\(migrationManager.getGuestDataPreview()?.backupCount ?? 0)")
                  .font(.appBodyLargeEmphasised)
                  .foregroundColor(.text01)
              }
            }
            .padding(20)
            .background(Color.surface)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            .padding(.horizontal, 20)

            // Action Buttons
            VStack(spacing: 12) {
              // Keep Data Button
              HabittoButton(
                size: .large,
                style: .fillPrimary,
                content: .text("Keep My Data"),
                state: migrationManager.isMigrating ? .disabled : .default,
                action: {
                  showingMultiDeviceWarning = true
                })
                .padding(.horizontal, 20)

              // Start Fresh Button
              HabittoButton(
                size: .large,
                style: .fillNeutral,
                content: .text("Start Fresh"),
                state: migrationManager.isMigrating ? .disabled : .default,
                action: {
                  Task {
                    await startFresh()
                  }
                })
                .padding(.horizontal, 20)
            }
          }
        } else {
          // No guest data found
          VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 48))
              .foregroundColor(.success)

            Text("No Data Found")
              .font(.appTitleLargeEmphasised)
              .foregroundColor(.text01)

            Text("You can start creating habits right away!")
              .font(.appBodyMedium)
              .foregroundColor(.text03)
              .multilineTextAlignment(.center)
          }
          .padding(24)
          .background(Color.surface)
          .cornerRadius(16)
          .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
          .padding(.horizontal, 20)
        }

        // Migration Progress
        if migrationManager.isMigrating {
          VStack(spacing: 12) {
            ProgressView(value: migrationManager.migrationProgress)
              .progressViewStyle(LinearProgressViewStyle())
              .tint(.primary)

            Text(migrationManager.migrationStatus)
              .font(.appBodySmall)
              .foregroundColor(.text03)
          }
          .padding(20)
          .background(Color.surface)
          .cornerRadius(16)
          .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
          .padding(.horizontal, 20)
        }

        Spacer(minLength: 40)
      }
      .padding(.bottom, 20)
    }
    .background(Color.surface2)
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

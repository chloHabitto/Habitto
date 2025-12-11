import SwiftUI

/// View for managing guest data migration when users create accounts
struct GuestDataMigrationView: View {
  // MARK: Internal

  // MARK: - Body

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        if isLoading {
          // Loading state
          VStack(spacing: 16) {
            ProgressView()
              .scaleEffect(1.5)
            Text("Checking your data...")
              .font(.appBodyMedium)
              .foregroundColor(.text03)
          }
          .padding(.top, 60)
        } else {
          // Determine scenario and show appropriate UI
          switch migrationScenario {
          case .bothCloudAndLocal:
            bothDataScenarioView
          case .cloudOnly:
            cloudOnlyScenarioView
          case .localOnly:
            localOnlyScenarioView
          case .noData:
            neitherScenarioView
          }
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
    .alert("Replace Account Data?", isPresented: $showingReplaceConfirmation) {
      Button("Cancel", role: .cancel) { }
      Button("Replace", role: .destructive) {
        Task {
          await migrateGuestData()
        }
      }
    } message: {
      if let cloudPreview = cloudDataPreview, let guestPreview = guestDataPreview {
        Text("This will permanently delete \(cloudPreview.habitCount) habit\(cloudPreview.habitCount == 1 ? "" : "s") from your account and replace them with the \(guestPreview.habitCount) habit\(guestPreview.habitCount == 1 ? "" : "s") on this device.")
      } else {
        Text("This will permanently delete your account data and replace it with the data on this device.")
      }
    }
    .task {
      await loadDataPreviews()
    }
  }

  // MARK: Private

  @StateObject private var migrationManager = GuestDataMigration()
  @State private var migrationError: String?
  @State private var showingError = false
  @State private var showingReplaceConfirmation = false
  @State private var isLoading = true
  @State private var cloudDataPreview: CloudDataPreview?
  @State private var guestDataPreview: GuestDataPreview?
  @State private var migrationScenario: MigrationScenario = .noData

  /// Repository for handling migration completion
  private let habitRepository = HabitRepository.shared

  // MARK: - Migration Scenarios

  enum MigrationScenario {
    case bothCloudAndLocal    // User has cloud data AND local guest data
    case cloudOnly            // User has cloud data but NO local guest data
    case localOnly            // User has local guest data but NO cloud data (new account)
    case noData               // No data anywhere (skip migration entirely)
  }

  // MARK: - Scenario Views

  /// Scenario 1: User has BOTH cloud data AND local guest data
  private var bothDataScenarioView: some View {
    VStack(spacing: 24) {
      // Header
      VStack(spacing: 16) {
        Text("Welcome Back!")
          .font(.appHeadlineMediumEmphasised)
          .foregroundColor(.text01)
          .multilineTextAlignment(.center)

        Text("We found your data in two places")
          .font(.appBodyMedium)
          .foregroundColor(.text03)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 20)
      }
      .padding(.top, 40)

      // Data Preview Cards
      VStack(spacing: 16) {
        // Your Account (cloud) card
        if let cloudPreview = cloudDataPreview {
          dataPreviewCard(
            icon: "cloud.fill",
            title: "Your Account",
            habitCount: cloudPreview.habitCount,
            level: cloudPreview.level,
            xp: cloudPreview.totalXP
          )
        }

        // This Device (local) card
        if let guestPreview = guestDataPreview {
          dataPreviewCard(
            icon: "iphone",
            title: "This Device",
            habitCount: guestPreview.habitCount,
            level: nil,
            xp: nil,
            isLocal: true
          )
        }
      }
      .padding(.horizontal, 20)

      // Question
      Text("What would you like to do?")
        .font(.appBodyLarge)
        .foregroundColor(.text01)
        .padding(.top, 8)

      // Action Buttons
      VStack(spacing: 12) {
        // Keep Both (recommended)
        HabittoButton(
          size: .large,
          style: .fillPrimary,
          content: .text("Keep Both"),
          state: migrationManager.isMigrating ? .disabled : .default,
          action: {
            Task {
              await mergeGuestDataWithCloud()
            }
          })
          .padding(.horizontal, 20)

        // Keep Account Data Only
        HabittoButton(
          size: .large,
          style: .fillNeutral,
          content: .text("Keep Account Data Only"),
          state: migrationManager.isMigrating ? .disabled : .default,
          action: {
            Task {
              await keepAccountData()
            }
          })
          .padding(.horizontal, 20)

        // Keep Local Data Only (needs confirmation)
        HabittoButton(
          size: .large,
          style: .fillTertiary,
          content: .text("Keep Local Data Only"),
          state: migrationManager.isMigrating ? .disabled : .default,
          action: {
            showingReplaceConfirmation = true
          })
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
    }
  }

  /// Scenario 2: User has ONLY cloud data (no local guest data)
  private var cloudOnlyScenarioView: some View {
    VStack(spacing: 24) {
      // Header
      VStack(spacing: 16) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 64))
          .foregroundColor(.success)

        Text("Welcome Back!")
          .font(.appHeadlineMediumEmphasised)
          .foregroundColor(.text01)
          .multilineTextAlignment(.center)

        if let cloudPreview = cloudDataPreview {
          VStack(spacing: 8) {
            HStack(spacing: 4) {
              Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.success)
              Text("\(cloudPreview.habitCount) habit\(cloudPreview.habitCount == 1 ? "" : "s") restored from your account")
                .font(.appBodyMedium)
                .foregroundColor(.text01)
            }
            Text("Level \(cloudPreview.level), \(cloudPreview.totalXP) XP")
              .font(.appBodyMedium)
              .foregroundColor(.text03)
          }
          .padding(.horizontal, 20)
        }
      }
      .padding(.top, 40)

      // Continue Button
      HabittoButton(
        size: .large,
        style: .fillPrimary,
        content: .text("Continue"),
        state: .default,
        action: {
          Task {
            await proceedWithoutMigration()
          }
        })
        .padding(.horizontal, 20)
    }
  }

  /// Scenario 3: User has ONLY local guest data (new account, no cloud data)
  private var localOnlyScenarioView: some View {
    VStack(spacing: 24) {
      // Header
      VStack(spacing: 16) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 64))
          .foregroundColor(.success)

        Text("Welcome!")
          .font(.appHeadlineMediumEmphasised)
          .foregroundColor(.text01)
          .multilineTextAlignment(.center)

        if let guestPreview = guestDataPreview {
          HStack(spacing: 4) {
            Image(systemName: "checkmark")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.success)
            Text("Your \(guestPreview.habitCount) habit\(guestPreview.habitCount == 1 ? "" : "s") will be saved to your new account")
              .font(.appBodyMedium)
              .foregroundColor(.text01)
          }
          .padding(.horizontal, 20)
        }
      }
      .padding(.top, 40)

      // Continue Button
      HabittoButton(
        size: .large,
        style: .fillPrimary,
        content: .text("Continue"),
        state: migrationManager.isMigrating ? .disabled : .default,
        action: {
          Task {
            await migrateGuestData()
          }
        })
        .padding(.horizontal, 20)

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
    }
  }

  /// Scenario 4: User has NO data at all (new account, no local data)
  private var neitherScenarioView: some View {
    VStack(spacing: 24) {
      // This scenario should skip the migration screen entirely
      // But if we're here, just show a simple continue button
      VStack(spacing: 16) {
        Text("Welcome!")
          .font(.appHeadlineMediumEmphasised)
          .foregroundColor(.text01)
          .multilineTextAlignment(.center)

        Text("You're all set! Start creating habits.")
          .font(.appBodyMedium)
          .foregroundColor(.text03)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 20)
      }
      .padding(.top, 40)

      HabittoButton(
        size: .large,
        style: .fillPrimary,
        content: .text("Continue"),
        state: .default,
        action: {
          Task {
            await proceedWithoutMigration()
          }
        })
        .padding(.horizontal, 20)
    }
  }

  // MARK: - Helper Views

  private func dataPreviewCard(
    icon: String,
    title: String,
    habitCount: Int,
    level: Int?,
    xp: Int?,
    isLocal: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 20))
          .foregroundColor(.primary)
          .frame(width: 24)

        Text(title)
          .font(.appBodyLargeEmphasised)
          .foregroundColor(.text01)

        Spacer()
      }

      Divider()
        .background(Color.outline2)

      HStack(spacing: 12) {
        Image(systemName: "list.bullet")
          .font(.system(size: 16))
          .foregroundColor(.text03)
          .frame(width: 20)

        Text("\(habitCount) habit\(habitCount == 1 ? "" : "s")")
          .font(.appBodyMedium)
          .foregroundColor(.text01)

        Spacer()
      }

      if let level = level, let xp = xp {
        HStack(spacing: 12) {
          Image(systemName: "star.fill")
            .font(.system(size: 16))
            .foregroundColor(.text03)
            .frame(width: 20)

          Text("Level \(level), \(xp) XP")
            .font(.appBodyMedium)
            .foregroundColor(.text01)

          Spacer()
        }
      } else if isLocal {
        HStack(spacing: 12) {
          Image(systemName: "clock")
            .font(.system(size: 16))
            .foregroundColor(.text03)
            .frame(width: 20)

          Text("Created before signing in")
            .font(.appBodyMedium)
            .foregroundColor(.text01)

          Spacer()
        }
      }
    }
    .padding(20)
    .background(Color.surface)
    .cornerRadius(16)
    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
  }

  // MARK: - Data Loading

  private func loadDataPreviews() async {
    isLoading = true

    // Load cloud data preview
    cloudDataPreview = await migrationManager.getCloudDataPreview()

    // Load guest data preview
    guestDataPreview = migrationManager.getGuestDataPreview()

    // Determine scenario
    let hasCloud = cloudDataPreview != nil && (cloudDataPreview?.habitCount ?? 0) > 0
    let hasLocal = guestDataPreview != nil && (guestDataPreview?.habitCount ?? 0) > 0

    let cloudHabitCount = cloudDataPreview?.habitCount ?? 0
    let localHabitCount = guestDataPreview?.habitCount ?? 0

    if hasCloud && hasLocal {
      migrationScenario = .bothCloudAndLocal
      print("🔍 [MIGRATION_SCENARIO] Detected: bothCloudAndLocal (\(localHabitCount) guest habit\(localHabitCount == 1 ? "" : "s"), \(cloudHabitCount) cloud habit\(cloudHabitCount == 1 ? "" : "s"))")
    } else if hasCloud {
      migrationScenario = .cloudOnly
      print("🔍 [MIGRATION_SCENARIO] Detected: cloudOnly (\(cloudHabitCount) cloud habit\(cloudHabitCount == 1 ? "" : "s"))")
    } else if hasLocal {
      migrationScenario = .localOnly
      print("🔍 [MIGRATION_SCENARIO] Detected: localOnly (\(localHabitCount) guest habit\(localHabitCount == 1 ? "" : "s"))")
    } else {
      migrationScenario = .noData
      print("🔍 [MIGRATION_SCENARIO] Detected: noData (no guest or cloud data)")
    }

    isLoading = false
  }

  // MARK: - Action Handlers

  private func mergeGuestDataWithCloud() async {
    let timestamp = Date()
    print("🔄 [MIGRATION_VIEW] \(timestamp) mergeGuestDataWithCloud() - START")
    print("   User chose: Keep Both (merging guest data with cloud data)")

    do {
      print("🔄 [MIGRATION_VIEW] \(timestamp) Calling migrationManager.mergeGuestDataWithCloud()...")
      try await migrationManager.mergeGuestDataWithCloud()

      let migrationCompleteTimestamp = Date()
      let migrationDuration = migrationCompleteTimestamp.timeIntervalSince(timestamp)
      print("✅ [MIGRATION_VIEW] \(migrationCompleteTimestamp) Merge completed successfully (took \(String(format: "%.2f", migrationDuration))s)")
      print("   Guest data merged with cloud data (all habits preserved)")

      print("🔄 [MIGRATION_VIEW] \(migrationCompleteTimestamp) Calling habitRepository.handleMigrationCompleted()...")
      await habitRepository.handleMigrationCompleted()

      let handlerCompleteTimestamp = Date()
      let handlerDuration = handlerCompleteTimestamp.timeIntervalSince(migrationCompleteTimestamp)
      print("✅ [MIGRATION_VIEW] \(handlerCompleteTimestamp) handleMigrationCompleted() finished (took \(String(format: "%.2f", handlerDuration))s)")
      print("✅ [MIGRATION_VIEW] \(handlerCompleteTimestamp) Merge flow complete - UI should now show merged habits")
      print("✅ [MIGRATION_VIEW] \(handlerCompleteTimestamp) Migration view should now be dismissed")

    } catch {
      let errorTimestamp = Date()
      print("❌ [MIGRATION_VIEW] \(errorTimestamp) Merge failed: \(error.localizedDescription)")
      migrationError = error.localizedDescription
      showingError = true
    }
  }

  private func keepAccountData() async {
    let timestamp = Date()
    print("🔄 [MIGRATION_VIEW] \(timestamp) keepAccountData() - START")
    print("   User chose: Keep Account Data Only (clearing guest data, keeping cloud data)")

    do {
      print("🔄 [MIGRATION_VIEW] \(timestamp) Calling migrationManager.clearGuestDataOnly()...")
      try await migrationManager.clearGuestDataOnly()

      let completeTimestamp = Date()
      let duration = completeTimestamp.timeIntervalSince(timestamp)
      print("✅ [MIGRATION_VIEW] \(completeTimestamp) keepAccountData() - COMPLETE (took \(String(format: "%.2f", duration))s)")
      print("   Guest data cleared, cloud data preserved")

      print("🔄 [MIGRATION_VIEW] \(completeTimestamp) Calling habitRepository.handleStartFresh()...")
      await habitRepository.handleStartFresh()
      print("✅ [MIGRATION_VIEW] \(Date()) Migration view should now be dismissed")

    } catch {
      let errorTimestamp = Date()
      print("❌ [MIGRATION_VIEW] \(errorTimestamp) keepAccountData() failed: \(error.localizedDescription)")
      migrationError = error.localizedDescription
      showingError = true
    }
  }

  private func migrateGuestData() async {
    let timestamp = Date()
    print("🔄 [MIGRATION_VIEW] \(timestamp) migrateGuestData() - START")
    print("   User chose: Keep Local Data Only (replacing cloud data with local data)")

    do {
      print("🔄 [MIGRATION_VIEW] \(timestamp) Calling migrationManager.migrateGuestData()...")
      print("   This will delete cloud data and migrate local guest data to account")
      try await migrationManager.migrateGuestData()

      let migrationCompleteTimestamp = Date()
      let migrationDuration = migrationCompleteTimestamp.timeIntervalSince(timestamp)
      print("✅ [MIGRATION_VIEW] \(migrationCompleteTimestamp) Migration completed successfully (took \(String(format: "%.2f", migrationDuration))s)")
      print("   Cloud data replaced with local data")

      print("🔄 [MIGRATION_VIEW] \(migrationCompleteTimestamp) Calling habitRepository.handleMigrationCompleted()...")
      await habitRepository.handleMigrationCompleted()

      let handlerCompleteTimestamp = Date()
      let handlerDuration = handlerCompleteTimestamp.timeIntervalSince(migrationCompleteTimestamp)
      print("✅ [MIGRATION_VIEW] \(handlerCompleteTimestamp) handleMigrationCompleted() finished (took \(String(format: "%.2f", handlerDuration))s)")
      print("✅ [MIGRATION_VIEW] \(handlerCompleteTimestamp) Migration flow complete - UI should now show migrated habits")
      print("✅ [MIGRATION_VIEW] \(handlerCompleteTimestamp) Migration view should now be dismissed")

    } catch {
      let errorTimestamp = Date()
      print("❌ [MIGRATION_VIEW] \(errorTimestamp) Migration failed: \(error.localizedDescription)")
      migrationError = error.localizedDescription
      showingError = true
    }
  }

  private func proceedWithoutMigration() async {
    let timestamp = Date()
    print("🔄 [MIGRATION_VIEW] \(timestamp) proceedWithoutMigration() - START")
    print("🔄 GuestDataMigrationView: User proceeding without migration")

    await habitRepository.handleStartFresh()

    let endTimestamp = Date()
    let duration = endTimestamp.timeIntervalSince(timestamp)
    print("✅ [MIGRATION_VIEW] \(endTimestamp) proceedWithoutMigration() - COMPLETE (took \(String(format: "%.2f", duration))s)")
  }
}

// MARK: - Preview

#Preview {
  NavigationView {
    GuestDataMigrationView()
  }
}

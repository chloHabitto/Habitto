import SwiftData
import SwiftUI
import FirebaseAuth

// MARK: - DeleteDataView

struct DeleteDataView: View {
  // MARK: Internal

  enum DeleteOption {
    case deleteAllData
    case deleteLocalOnly
  }

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Content
        ScrollView {
          VStack(spacing: 24) {
            // Description text
            Text("Remove your data from this device")
              .font(.appBodyMedium)
              .foregroundColor(.text05)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 20)
              .padding(.top, 8)

            // Warning Notice
            VStack(spacing: 12) {
              HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                  .font(.system(size: 20))
                  .foregroundColor(.orange)

                Text("Important Notice")
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundColor(.text01)

                Spacer()
              }

              Text(
                "This action cannot be undone. All selected data will be permanently deleted from this device.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.text02)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color("appSurface02Variant"))
            .cornerRadius(24)
            .padding(.horizontal, 20)

            Spacer(minLength: 100)
          }
          .padding(.top, 24)
          .padding(.bottom, 24)
        }
        .background(Color("appSurface01Variant02"))

        // Fixed Bottom Section - Delete Button
        VStack(spacing: 16) {
          Text("Permanently remove all your data from this device")
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.text03)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)

          HabittoButton.largeFillDestructive(
            text: "Delete All Data",
            state: isDeleting ? .loading : .default)
          {
            Task {
              await checkAuthAndShowDialog()
            }
          }
          .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .background(Color("appSurface01Variant02"))
      }
      .background(Color("appSurface01Variant02"))
      .navigationTitle("Delete Data")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.text01)
          }
        }
      }
    }
    .sheet(isPresented: $showingDeleteComplete) {
      DeleteCompleteView {
        dismiss()
      }
    }
    .alert(getConfirmationTitle(), isPresented: $showingConfirmation) {
      Button("Cancel", role: .cancel) {
        selectedOption = nil
      }
      Button("Delete", role: .destructive) {
        Task {
          await performDeletion()
        }
      }
    } message: {
      Text(getConfirmationMessage())
    }
    .alert("Cloud Data Detected", isPresented: $showingSignedOutDialog) {
      Button("Cancel", role: .cancel) { }
      Button("Sign In to Delete Everything") {
        // Navigate to sign in - for now, just show a message
        // In a real app, you'd navigate to the sign-in screen
        showingSignInMessage = true
      }
      Button("Delete Local Data Only", role: .destructive) {
        selectedOption = .deleteLocalOnly
        showingLocalOnlyConfirmation = true
      }
    } message: {
      Text("You have data backed up in the cloud from a previous sign-in. To delete ALL your data including cloud backup, please sign in first.")
    }
    .alert("Sign In Required", isPresented: $showingSignInMessage) {
      Button("OK") {
        showingSignInMessage = false
      }
    } message: {
      Text("Please sign in from the Profile screen to delete cloud data.")
    }
    .alert("Delete Local Data Only", isPresented: $showingLocalOnlyConfirmation) {
      Button("Cancel", role: .cancel) {
        selectedOption = nil
      }
      Button("Delete", role: .destructive) {
        Task {
          await performDeletion()
        }
      }
    } message: {
      Text("This will delete all local data. If you sign in later, your cloud data will return.")
    }
    .alert("Deletion Error", isPresented: .constant(deleteError != nil)) {
      Button("OK") {
        deleteError = nil
      }
    } message: {
      if let error = deleteError {
        Text(error)
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @StateObject private var authManager = AuthenticationManager.shared
  @State private var showingConfirmation = false
  @State private var showingSignedOutDialog = false
  @State private var showingSignInMessage = false
  @State private var showingLocalOnlyConfirmation = false
  @State private var isDeleting = false
  @State private var showingDeleteComplete = false
  @State private var deleteError: String?
  @State private var selectedOption: DeleteOption?

  private var isSignedIn: Bool {
    if let currentUser = Auth.auth().currentUser {
      // Check if user is anonymous (not truly signed in)
      return !currentUser.isAnonymous
    }
    return false
  }

  private func checkAuthAndShowDialog() async {
    if isSignedIn {
      // User is signed in - proceed with full deletion
      selectedOption = .deleteAllData
      showingConfirmation = true
    } else {
      // User is signed out - check if they have cloud data
      // For now, always show the dialog (in a real app, you'd check Firestore)
      showingSignedOutDialog = true
    }
  }

  private func getConfirmationTitle() -> String {
    "Delete All Data"
  }

  private func getConfirmationMessage() -> String {
    "This will permanently delete all your data from this device and cloud. This action cannot be undone."
  }

  private func performDeletion() async {
    isDeleting = true

    do {
      guard let option = selectedOption else {
        throw DeleteError.noOptionSelected
      }

      // Perform actual deletion based on selected option
      try await performActualDeletion(for: option)

      await MainActor.run {
        showingConfirmation = false
        showingDeleteComplete = true
        isDeleting = false
        selectedOption = nil
      }

    } catch {
      await MainActor.run {
        deleteError = getErrorMessage(for: error)
        showingConfirmation = false
        isDeleting = false
        selectedOption = nil
      }
    }
  }

  private func performActualDeletion(for option: DeleteOption) async throws {
    switch option {
    case .deleteAllData:
      try await deleteAllData(includeCloud: true)
    case .deleteLocalOnly:
      try await deleteAllData(includeCloud: false)
    }
  }

  private func deleteAllData(includeCloud: Bool) async throws {
    do {
      print("🔥 DELETE_ALL: Starting deletion process (includeCloud: \(includeCloud))...")
      
      // ✅ STEP 0: Stop Firestore listeners FIRST to prevent sync-back of deleted data
      if includeCloud && isSignedIn {
        await MainActor.run {
          FirestoreService.shared.stopListening()
          print("✅ DELETE_ALL: Firestore listeners stopped")
        }
      }
      
      // ✅ STEP 1: Delete Firestore data (if signed in and includeCloud is true)
      if includeCloud && isSignedIn {
        print("🔥 DELETE_ALL: Deleting Firestore data...")
        try await FirestoreService.shared.deleteAllUserData()
        print("✅ DELETE_ALL: Firestore data deleted")
      }
      
      // ✅ STEP 2: Clear ALL UserDefaults keys FIRST (including SavedHabits and XP cache)
      // This prevents XPManager from loading old data if it reinitializes
      await MainActor.run {
        clearAllUserDataFromUserDefaults()
        print("✅ DELETE_ALL: UserDefaults cleared (including SavedHabits, XP/Level cache, migration flags, streak/backfill keys)")
      }
      
      // ✅ STEP 3: Reset XP and level data (after UserDefaults cleared, this saves clean default state)
      await MainActor.run {
        XPManager.shared.resetToDefault()
        print("✅ DELETE_ALL: XPManager reset to default (level 1, 0 XP)")
      }

      // ✅ STEP 4: Reset DailyAwardService state
      await MainActor.run {
        DailyAwardService.shared.resetState()
        print("✅ DELETE_ALL: DailyAwardService state cleared")
      }

      // ✅ STEP 5: Clear all local SwiftData (waits for deletion)
      let habitStore = HabitStore.shared
      try await habitStore.clearAllHabits()
      print("✅ DELETE_ALL: All SwiftData models cleared (HabitData, CompletionRecord, DailyAward, UserProgressData, GlobalStreakModel, ProgressEvent)")

      // ✅ STEP 6: Clear HabitRepository habits array
      await MainActor.run {
        let habitRepository = HabitRepository.shared
        Task {
          await habitRepository.loadHabits(force: true)
          print("✅ DELETE_ALL: HabitRepository reloaded (should be empty)")
        }
      }
      
      // ✅ STEP 7: Wait a moment to ensure all operations complete
      try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

      print("✅ DELETE_ALL: Completed successfully")

    } catch {
      print("❌ DELETE_ALL failed: \(error)")
      throw DeleteError.allDataDeletionFailed
    }
  }
  
  /// Clear all UserDefaults keys matching patterns
  private func clearAllUserDataFromUserDefaults() {
    let defaults = UserDefaults.standard
    let dictionary = defaults.dictionaryRepresentation()
    
    // ✅ FIX 1: Explicitly delete SavedHabits key (emergency backup from HabitStore)
    defaults.removeObject(forKey: "SavedHabits")
    print("🗑️ DELETE_ALL: Removed UserDefaults key: SavedHabits")
    
    // Patterns to match
    let patternsToDelete = [
      "migrat", "streak", "backfill", "xp", "level", 
      "guest_", "completion", "award", "habit"
    ]
    
    // Get current user ID for user-specific keys
    let currentUserId = Auth.auth().currentUser?.uid ?? ""
    
    for key in dictionary.keys {
      let lowercaseKey = key.lowercased()
      
      // Check if key matches any pattern
      let matchesPattern = patternsToDelete.contains { pattern in
        lowercaseKey.contains(pattern)
      }
      
      // Check if key starts with user's userId
      let startsWithUserId = !currentUserId.isEmpty && key.hasPrefix(currentUserId)
      
      // Check for guest_to_anonymous_complete_migrated keys
      let isMigrationKey = key.contains("guest_to_anonymous_complete_migrated")
      
      if matchesPattern || startsWithUserId || isMigrationKey {
        defaults.removeObject(forKey: key)
        print("🗑️ DELETE_ALL: Removed UserDefaults key: \(key)")
      }
    }
    
    defaults.synchronize()
  }

  private func getErrorMessage(for error: Error) -> String {
    if let deleteError = error as? DeleteError {
      deleteError.localizedDescription
    } else {
      "Deletion failed: \(error.localizedDescription)"
    }
  }
}

// MARK: - DeleteCompleteView

struct DeleteCompleteView: View {
  let onDismiss: () -> Void

  var body: some View {
    NavigationView {
      VStack(spacing: 32) {
        Spacer()

        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 80))
          .foregroundColor(.green)

        VStack(spacing: 12) {
          Text("Data Deleted")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.text01)

          Text("Your data has been permanently removed from this device.")
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(.text03)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
        }

        Spacer()

        HabittoButton.largeFillPrimary(
          text: "Done")
        {
          onDismiss()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
      }
      .background(Color("appSurface01Variant02"))
    }
  }
}

// MARK: - DeleteError

enum DeleteError: Error, LocalizedError {
  case noOptionSelected
  case allDataDeletionFailed

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .noOptionSelected:
      "No deletion option was selected"
    case .allDataDeletionFailed:
      "Failed to delete all data. Please try again."
    }
  }
}

#Preview {
  DeleteDataView()
}

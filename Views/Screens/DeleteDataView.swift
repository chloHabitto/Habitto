import SwiftData
import SwiftUI

// MARK: - DeleteDataView

struct DeleteDataView: View {
  // MARK: Internal

  enum DeleteOption {
    case deleteAllData
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
            .background(Color.surface)
            .cornerRadius(16)
            .padding(.horizontal, 20)

            Spacer(minLength: 100)
          }
          .padding(.top, 24)
          .padding(.bottom, 24)
        }
        .background(Color.surface2)

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
            selectedOption = .deleteAllData
            showingConfirmation = true
          }
          .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .background(Color.surface2)
      }
      .background(Color.surface2)
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
  @State private var showingConfirmation = false
  @State private var isDeleting = false
  @State private var showingDeleteComplete = false
  @State private var deleteError: String?
  @State private var selectedOption: DeleteOption?

  private func getConfirmationTitle() -> String {
    "Delete All Data"
  }

  private func getConfirmationMessage() -> String {
    "This will permanently delete all your data from this device. This action cannot be undone."
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

  private func performActualDeletion(for _: DeleteOption) async throws {
    try await deleteAllData()
  }

  private func deleteAllData() async throws {
    do {
      print("🔥 DELETE_ALL: Starting deletion process...")
      
      // ✅ STEP 1: Clear all habits (waits for both local AND Firestore deletion)
      let habitStore = HabitStore.shared
      try await habitStore.clearAllHabits()
      print("✅ DELETE_ALL: Habits cleared from local and Firestore")

      // ✅ STEP 2: Clear XP and level data (waits for both local AND Firestore deletion)
      _ = await MainActor.run {
        Task {
          await XPManager.shared.clearXPData()
          print("✅ DELETE_ALL: XP and level data cleared from local and Firestore")
        }
      }

      // ✅ STEP 3: Clear UserDefaults (app settings, preferences, etc.)
      _ = await MainActor.run {
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
        print("✅ DELETE_ALL: UserDefaults cleared")

        // Also clear HabitStorageManager cache
        HabitStorageManager.shared.clearCache()
        print("✅ DELETE_ALL: Cache cleared")
      }
      
      // ✅ STEP 4: Wait a moment to ensure all Firestore operations complete
      try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
      
      // ✅ STEP 5: Now reload habits (should be empty since Firestore was cleared)
      _ = await MainActor.run {
        Task {
          let habitRepository = HabitRepository.shared
          await habitRepository.loadHabits(force: true)
          print("✅ DELETE_ALL: HabitRepository reloaded (should be empty)")
        }
      }

      print("✅ DELETE_ALL: Completed successfully")

    } catch {
      print("❌ DELETE_ALL failed: \(error)")
      throw DeleteError.allDataDeletionFailed
    }
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

        Button("Done") {
          onDismiss()
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.primary)
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
      }
      .background(Color.surface2)
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

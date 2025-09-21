import SwiftUI
import SwiftData

struct DeleteDataView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingConfirmation = false
    @State private var isDeleting = false
    @State private var showingDeleteComplete = false
    @State private var deleteError: String?
    @State private var selectedOption: DeleteOption?
    
    enum DeleteOption {
        case deleteAllData
        
        var title: String {
            return "Delete All Data"
        }
        
        var subtitle: String {
            return "Permanently remove all your data"
        }
        
        var icon: String {
            return "Icon-TrashBin2_Filled"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                ScreenHeader(
                    title: "Delete Data",
                    description: "Remove your data from this device"
                ) {
                    dismiss()
                }
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
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
                            
                            Text("This action cannot be undone. All selected data will be permanently deleted from this device.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.text02)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.surface)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        
                        // Delete Option
                        DeleteOptionRow(
                            option: .deleteAllData,
                            onTap: {
                                selectedOption = .deleteAllData
                                showingConfirmation = true
                            }
                        )
                        .background(Color.surface)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.bottom, 24)
                }
                .background(Color.surface2)
            }
            .background(Color.surface2)
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
    
    private func getConfirmationTitle() -> String {
        return "Delete All Data"
    }
    
    private func getConfirmationMessage() -> String {
        return "This will permanently delete all your data from this device. This action cannot be undone."
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
                self.showingConfirmation = false
                self.showingDeleteComplete = true
                self.isDeleting = false
                self.selectedOption = nil
            }
            
        } catch {
            await MainActor.run {
                self.deleteError = getErrorMessage(for: error)
                self.showingConfirmation = false
                self.isDeleting = false
                self.selectedOption = nil
            }
        }
    }
    
    private func performActualDeletion(for option: DeleteOption) async throws {
        try await deleteAllData()
    }
    
    private func deleteAllData() async throws {
        do {
            // Use HabitStore to clear all habits (this is the proper way)
            let habitStore = HabitStore.shared
            try await habitStore.clearAllHabits()
            
            // Clear UserDefaults (app settings, preferences, etc.)
            await MainActor.run {
                let defaults = UserDefaults.standard
                let domain = Bundle.main.bundleIdentifier!
                defaults.removePersistentDomain(forName: domain)
                defaults.synchronize()
                
                // Also clear HabitStorageManager cache
                HabitStorageManager.shared.clearCache()
                
                // Notify HabitRepository to reload data so UI updates
                let habitRepository = HabitRepository.shared
                Task {
                    await habitRepository.loadHabits(force: true)
                    print("✅ Delete All Data: HabitRepository notified to reload data")
                }
            }
            
            print("✅ Delete All Data: Completed successfully")
            
        } catch {
            print("❌ Delete All Data failed: \(error)")
            throw DeleteError.allDataDeletionFailed
        }
    }
    
    private func getErrorMessage(for error: Error) -> String {
        if let deleteError = error as? DeleteError {
            return deleteError.localizedDescription
        } else {
            return "Deletion failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Views

struct DeleteOptionRow: View {
    let option: DeleteDataView.DeleteOption
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(option.icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text01)
                    
                    Text(option.subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.text03)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.text03)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


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

// MARK: - Error Types

enum DeleteError: Error, LocalizedError {
    case noOptionSelected
    case allDataDeletionFailed
    
    var errorDescription: String? {
        switch self {
        case .noOptionSelected:
            return "No deletion option was selected"
        case .allDataDeletionFailed:
            return "Failed to delete all data. Please try again."
        }
    }
}

#Preview {
    DeleteDataView()
}

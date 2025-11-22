import SwiftUI
import FirebaseAuth

// MARK: - AccountView

struct AccountView: View {
  // MARK: Internal

  @EnvironmentObject var authManager: AuthenticationManager

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Main content area
        if isLoggedIn {
          // Account Options for authenticated users
          VStack(spacing: 0) {
            ScrollView {
              VStack(spacing: 24) {
                // ✅ TEMPORARY DEBUG: Sign-in verification info (remove after testing)
                debugSignInInfo
                
                // ✅ TEMPORARY DEBUG: Force sync button (remove after testing)
                forceSyncButton
                
                // Description text
                Text("Manage your account preferences")
                  .font(.appBodyMedium)
                  .foregroundColor(.text05)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 20)
                  .padding(.top, 8)
                
                .background(Color.surface)
                .cornerRadius(16)
                .padding(.horizontal, 20)

                // Developer Tools Section (DEBUG only)
                #if DEBUG
                VStack(spacing: 0) {
                  AccountOptionRow(
                    icon: "ant.circle.fill",
                    title: "Debug User Statistics",
                    subtitle: "View database and user state analysis",
                    hasChevron: true,
                    iconColor: .orange)
                  {
                    Task {
                      await HabitRepository.shared.debugUserStats()
                      showingDebugAlert = true
                    }
                  }
                  
                  Divider()
                    .padding(.leading, 56)
                  
                  AccountOptionRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Migration Debug",
                    subtitle: "Test data migration system",
                    hasChevron: true,
                    iconColor: .blue)
                  {
                    showingMigrationDebug = true
                  }
                  
                  Divider()
                    .padding(.leading, 56)
                  
                  AccountOptionRow(
                    icon: "flag.fill",
                    title: "Feature Flags",
                    subtitle: "Toggle new architecture features",
                    hasChevron: true,
                    iconColor: .green)
                  {
                    showingFeatureFlags = true
                  }
                }
                .background(Color.surface)
                .cornerRadius(16)
                .padding(.horizontal, 20)
                #endif

                Spacer(minLength: 40)
              }
              .padding(.bottom, 20)
            }

            // Account Actions Section - Fixed at bottom
            VStack(spacing: 16) {
              // Sign Out Button
              HabittoButton(
                size: .large,
                style: .fillTertiary,
                content: .text("Sign Out"),
                action: {
                  showingSignOutAlert = true
                })

              // Delete Account Button
              HabittoButton(
                size: .large,
                style: .fillDestructive,
                content: .text("Delete Account"),
                action: {
                  showingDeleteAccountConfirmation = true
                })
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .background(Color.surface2)
          }
        } else {
          // Guest mode - Sign in with Apple
          VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
              // Icon
              Image(systemName: "person.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.text04)
              
              // Title
              Text("Sign in to sync across devices")
                .font(.appTitleLarge)
                .foregroundColor(.text01)
                .multilineTextAlignment(.center)
              
              // Description
              Text("Sign in with Apple to enable cross-device sync and keep your habits safe in the cloud.")
                .font(.appBodyMedium)
                .foregroundColor(.text03)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
              
              // Sign in with Apple button
              SignInWithAppleButton()
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
            
            Spacer()
          }
        }
      }
      .background(Color.surface2)
      .navigationTitle("Account")
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
    .sheet(isPresented: $showingDataPrivacy) {
      DataPrivacyView()
    }
    .sheet(isPresented: $showingDeleteAccountConfirmation) {
      AccountDeletionConfirmationView()
    }
    .alert("Sign Out", isPresented: $showingSignOutAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Sign Out", role: .destructive) {
        authManager.signOut()
        dismiss()
      }
    } message: {
      Text("Are you sure you want to sign out?")
    }
    .alert("Debug Report Generated", isPresented: $showingDebugAlert) {
      Button("OK", role: .cancel) { }
    } message: {
      Text("Check the Xcode console to see the detailed user statistics report.")
    }
    .sheet(isPresented: $showingMigrationDebug) {
      NavigationStack {
        MigrationDebugView()
      }
    }
    .sheet(isPresented: $showingFeatureFlags) {
      NavigationStack {
        FeatureFlagsDebugView()
      }
    }
    .alert("Sync Status", isPresented: $showingSyncAlert) {
      Button("OK", role: .cancel) { }
    } message: {
      Text(syncStatusMessage.isEmpty ? "Sync completed" : syncStatusMessage)
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss

  // State variables for showing different screens
  @State private var showingDataPrivacy = false
  @State private var showingSignOutAlert = false
  @State private var showingDeleteAccountConfirmation = false
  @State private var showingDebugAlert = false
  @State private var showingMigrationDebug = false
  @State private var showingFeatureFlags = false
  @State private var isSyncing = false
  @State private var syncStatusMessage = ""
  @State private var showingSyncAlert = false

  // ✅ TEMPORARY DEBUG: Force sync button (remove after testing)
  private var forceSyncButton: some View {
    VStack(spacing: 12) {
      Button(action: {
        Task {
          await performForceSync()
        }
      }) {
        HStack {
          if isSyncing {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .white))
              .scaleEffect(0.8)
          } else {
            Image(systemName: "arrow.clockwise")
              .font(.system(size: 16, weight: .semibold))
          }
          
          Text(isSyncing ? "Syncing..." : "Force Sync Now")
            .font(.system(size: 16, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(isSyncing ? Color.gray : Color.blue)
        .cornerRadius(12)
      }
      .disabled(isSyncing)
      
      if !syncStatusMessage.isEmpty {
        Text(syncStatusMessage)
          .font(.system(size: 12, weight: .regular))
          .foregroundColor(.text03)
          .multilineTextAlignment(.center)
      }
    }
    .padding(.horizontal, 20)
  }
  
  // ✅ TEMPORARY DEBUG: Force sync function (remove after testing)
  private func performForceSync() async {
    guard let userId = Auth.auth().currentUser?.uid else {
      syncStatusMessage = "Error: No authenticated user"
      showingSyncAlert = true
      return
    }
    
    isSyncing = true
    syncStatusMessage = "Starting sync..."
    
    do {
      // Force pull all data by resetting last sync timestamp first
      await resetLastSyncTimestamp(userId: userId)
      
      // Perform full sync cycle
      try await SyncEngine.shared.performFullSyncCycle(userId: userId)
      
      // Get pull summary to show what was synced
      let summary = try await SyncEngine.shared.pullRemoteChanges(userId: userId)
      
      syncStatusMessage = """
        ✅ Sync Complete!
        Habits: \(summary.habitsPulled)
        Completions: \(summary.completionsPulled)
        Awards: \(summary.awardsPulled)
        Events: \(summary.eventsPulled)
        """
      
      if !summary.errors.isEmpty {
        syncStatusMessage += "\n⚠️ Errors: \(summary.errors.joined(separator: ", "))"
      }
      
      showingSyncAlert = true
      
      // Reload habits to show synced data
      await HabitRepository.shared.loadHabits(force: true)
      
    } catch {
      syncStatusMessage = "❌ Sync failed: \(error.localizedDescription)"
      showingSyncAlert = true
    }
    
    isSyncing = false
  }
  
  // ✅ TEMPORARY DEBUG: Reset last sync timestamp to force pull all data (remove after testing)
  private func resetLastSyncTimestamp(userId: String) async {
    await SyncEngine.shared.resetLastSyncTimestamp(userId: userId)
  }

  // ✅ TEMPORARY DEBUG: Sign-in verification info view (remove after testing)
  private var debugSignInInfo: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("DEBUG INFO:")
        .font(.system(size: 14, weight: .bold))
        .foregroundColor(.orange)
      
      if let firebaseUser = Auth.auth().currentUser {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("User ID:")
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(.text03)
            Spacer()
            Text("\(firebaseUser.uid.prefix(8))...")
              .font(.system(size: 12, weight: .regular))
              .foregroundColor(.text01)
          }
          
          HStack {
            Text("Anonymous:")
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(.text03)
            Spacer()
            Text(firebaseUser.isAnonymous ? "true" : "false")
              .font(.system(size: 12, weight: .regular))
              .foregroundColor(firebaseUser.isAnonymous ? .orange : .green)
          }
          
          HStack {
            Text("Email:")
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(.text03)
            Spacer()
            Text(firebaseUser.email ?? "Not provided")
              .font(.system(size: 12, weight: .regular))
              .foregroundColor(.text01)
          }
          
          HStack {
            Text("Provider:")
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(.text03)
            Spacer()
            Text(providerName(for: firebaseUser))
              .font(.system(size: 12, weight: .regular))
              .foregroundColor(.text01)
          }
        }
      } else {
        Text("No Firebase user found")
          .font(.system(size: 12, weight: .regular))
          .foregroundColor(.red)
      }
    }
    .padding(16)
    .background(Color.orange.opacity(0.1))
    .cornerRadius(12)
    .padding(.horizontal, 20)
    .padding(.top, 8)
  }
  
  // ✅ TEMPORARY DEBUG: Helper to get provider name (remove after testing)
  private func providerName(for user: User) -> String {
    guard !user.providerData.isEmpty else {
      return user.isAnonymous ? "anonymous" : "unknown"
    }
    
    // Get the first provider (usually the main one)
    if let provider = user.providerData.first {
      return provider.providerID
    }
    
    return "unknown"
  }

  private var isLoggedIn: Bool {
    switch authManager.authState {
    case .authenticated(let user):
      // ✅ FIX: Show guest view if user is anonymous (not truly logged in)
      // Check if Firebase user is anonymous
      if let firebaseUser = user as? User, firebaseUser.isAnonymous {
        return false  // Anonymous users should see guest view
      }
      return true  // Real authenticated users (email, Google, Apple)
    case .authenticating,
         .error,
         .unauthenticated:
      return false
    }
  }
}

// MARK: - AccountOptionRow

struct AccountOptionRow: View {
  // MARK: Lifecycle

  init(
    icon: String,
    title: String,
    subtitle: String,
    hasChevron: Bool,
    iconColor: Color = .navy200,
    action: @escaping () -> Void)
  {
    self.icon = icon
    self.title = title
    self.subtitle = subtitle
    self.hasChevron = hasChevron
    self.iconColor = iconColor
    self.action = action
  }

  // MARK: Internal

  let icon: String
  let title: String
  let subtitle: String
  let hasChevron: Bool
  let iconColor: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        if icon.hasPrefix("Icon-") {
          // Custom icon
          Image(icon)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 24)
            .foregroundColor(iconColor)
        } else {
          // System icon
          Image(systemName: icon)
            .font(.system(size: 20))
            .foregroundColor(iconColor)
            .frame(width: 24)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.appBodyLarge)
            .foregroundColor(.text01)

          Text(subtitle)
            .font(.appBodySmall)
            .foregroundColor(.text03)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if hasChevron {
          Image(systemName: "chevron.right")
            .font(.system(size: 16))
            .foregroundColor(.text03)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .contentShape(Rectangle())
    }
    .buttonStyle(PlainButtonStyle())
  }
}

#Preview {
  AccountView()
    .environmentObject(AuthenticationManager.shared)
}

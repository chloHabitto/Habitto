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
          ZStack(alignment: .bottom) {
            ScrollView {
              VStack(spacing: 24) {
                // Profile Section
                profileSection
                  .padding(.top, 20)
                
                // User Information Section
                userInformationSection
                
                // Login Information Section
                loginInformationSection
                
                // Spacer for bottom button
                Spacer(minLength: 100)
              }
              .padding(.horizontal, 20)
              .padding(.top, 0)
              .padding(.bottom, 20)
            }
            
            // Log out Button - Fixed at bottom
            logOutButton
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
      .background(Color("appSurface01Variant02"))
      .navigationTitle("Account")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "chevron.left")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.text01)
          }
        }
      }
    }
    .sheet(isPresented: $showingDataPrivacy) {
      DataPrivacyView()
    }
    .sheet(isPresented: $showingPhotoOptions) {
      PhotoOptionsBottomSheet(
        onClose: {
          showingPhotoOptions = false
        },
        onAvatarSelection: {
          showingAvatarSelection = true
        },
        onTakePhoto: {
          requestCameraPermissionAndOpen()
        },
        onChooseFromLibrary: {
          requestPhotoLibraryPermissionAndOpen()
        })
    }
    .sheet(isPresented: $showingAvatarSelection) {
      AvatarSelectionView()
    }
    .sheet(isPresented: $showingCamera) {
      if permissionManager.canUseCamera {
        CameraView { image in
          avatarManager.selectCustomPhoto(image)
        }
      } else {
        VStack(spacing: 20) {
          Image(systemName: "camera.fill")
            .font(.system(size: 60))
            .foregroundColor(.text03)

          Text("Camera Not Available")
            .font(.appTitleMedium)
            .foregroundColor(.text01)

          Text("Camera is not available or permission is required.")
            .font(.appBodyMedium)
            .foregroundColor(.text02)
            .multilineTextAlignment(.center)

          Button("OK") {
            showingCamera = false
          }
          .font(.appLabelLarge)
          .foregroundColor(.primary)
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .background(Color.primary.opacity(0.1))
          .cornerRadius(25)
        }
        .padding(40)
      }
    }
    .sheet(isPresented: $showingPhotoLibrary) {
      PhotoLibraryView { image in
        avatarManager.selectCustomPhoto(image)
      }
    }
    .sheet(isPresented: $showingNameEditSheet) {
      NameEditBottomSheet(
        name: $editedName,
        isFocused: $isNameFieldFocused,
        onClose: {
          showingNameEditSheet = false
        },
        onSave: {
          saveName()
        })
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
    .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Delete Account", role: .destructive) {
        Task {
          await performAccountDeletion()
        }
      }
    } message: {
      Text("Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.")
    }
    .alert("Deletion Error", isPresented: $showingDeletionError) {
      Button("OK") {
        deletionError = nil
        showingDeletionError = false
      }
    } message: {
      Text(deletionError ?? "An unknown error occurred")
    }
    .alert("Account Deleted", isPresented: $showingDeletionSuccess) {
      Button("OK") {
        dismiss()
      }
    } message: {
      Text("Your account has been deleted successfully. You have been signed out.")
    }
    .alert("Repair Data", isPresented: $showingRepairAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Repair", role: .destructive) {
        Task {
          await performDataRepair()
        }
      }
    } message: {
      Text(repairMessage)
    }
    .alert("Repair Complete", isPresented: $showingRepairSuccess) {
      Button("OK") {
        // Reload habits to show migrated data
        Task {
          await HabitRepository.shared.loadHabits(force: true)
        }
      }
    } message: {
      Text(repairSuccessMessage)
    }
    .alert("Repair Error", isPresented: $showingRepairError) {
      Button("OK") {
        repairError = nil
      }
    } message: {
      Text(repairError ?? "An unknown error occurred")
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var avatarManager = AvatarManager.shared
  @ObservedObject private var permissionManager = PermissionManager.shared

  // State variables for showing different screens
  @State private var showingDataPrivacy = false
  @State private var showingSignOutAlert = false
  @State private var showingDeleteAccountAlert = false
  @State private var isDeletingAccount = false
  @State private var deletionError: String?
  @State private var showingDeletionError = false
  @State private var showingDeletionSuccess = false
  @State private var showingPhotoOptions = false
  @State private var showingAvatarSelection = false
  @State private var showingCamera = false
  @State private var showingPhotoLibrary = false
  @State private var showingNameEditSheet = false
  @State private var editedName = ""
  @FocusState private var isNameFieldFocused: Bool
  @State private var showingBirthdayView = false
  @State private var selectedBirthday: Date = Date()
  @State private var hasSetBirthday = false
  @State private var showingGenderView = false
  @State private var userID: String = ""
  @State private var copiedUserID = false
  @State private var copiedEmail = false
  
  // Data Repair state
  @State private var showingRepairAlert = false
  @State private var repairMessage = ""
  @State private var showingRepairSuccess = false
  @State private var repairSuccessMessage = ""
  @State private var showingRepairError = false
  @State private var repairError: String?
  @State private var isRepairing = false
  
  @StateObject private var deletionService = AccountDeletionService()
  private let repairService = DataRepairService.shared

  // MARK: - Profile Section
  
  private var profileSection: some View {
    VStack(spacing: 16) {
      // Profile Picture
      Button(action: {
        showingPhotoOptions = true
      }) {
        ZStack(alignment: .bottomTrailing) {
          Group {
            if avatarManager.selectedAvatar.isCustomPhoto,
               let imageData = avatarManager.selectedAvatar.customPhotoData,
               let uiImage = UIImage(data: imageData)
            {
              Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
            } else {
              Image(avatarManager.selectedAvatar.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
            }
          }
          .frame(width: 80, height: 80)
          .clipShape(Circle())
          .overlay(
            Circle()
              .stroke(Color.appOutline02, lineWidth: 3))
          
          // Edit Icon
          Image("Icon-Pen_Filled")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
            .foregroundColor(.appPrimary)
            .padding(6)
            .background(Color.primaryContainer)
            .clipShape(Circle())
            .overlay(
              Circle()
                .stroke(Color.appOutline02, lineWidth: 2))
        }
      }
      .buttonStyle(PlainButtonStyle())
      
      // Name with edit icon - clickable button
      Button(action: {
        editedName = userDisplayName == "User" ? "" : userDisplayName
        showingNameEditSheet = true
      }) {
        HStack(spacing: 8) {
          Text(userDisplayName)
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.text01)
          
          Image("Icon-Pen_Filled")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 14, height: 14)
            .foregroundColor(.text01)
        }
      }
      .buttonStyle(PlainButtonStyle())
    }
    .frame(maxWidth: .infinity)
    .onAppear {
      loadUserID()
      loadBirthday()
    }
  }
  
  private func loadBirthday() {
    // Load birthday from UserDefaults if available
    if let savedBirthday = UserDefaults.standard.object(forKey: "UserBirthday") as? Date {
      selectedBirthday = savedBirthday
      hasSetBirthday = true
    }
  }
  
  // MARK: - User Information Section
  
  private var userInformationSection: some View {
    VStack(spacing: 0) {
      // User ID Row - Custom layout with VStack for title and value
      HStack(spacing: 12) {
        // Icon
        Image(systemName: "person.fill")
          .font(.system(size: 20))
          .foregroundColor(.appIconColor)
          .frame(width: 24, height: 24)
        
        // Title and Value in VStack
        VStack(alignment: .leading, spacing: 4) {
          Text("User ID")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.text01)
          
          Text(userID.isEmpty ? "Loading..." : userID)
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.text04)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        // Copy button
        Button(action: {
          copyUserID()
        }) {
          Text(copiedUserID ? "Copied" : "Copy")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.primary)
        }
        .buttonStyle(PlainButtonStyle())
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      
      Divider()
        .padding(.leading, 56)
      
      // Birthday Row - Custom layout to show date below title
      Button(action: {
        showingBirthdayView = true
      }) {
        HStack(spacing: 12) {
          // Icon
          Image(systemName: "gift.fill")
            .font(.system(size: 20))
            .foregroundColor(.appIconColor)
            .frame(width: 24, height: 24)
          
          // Title and Value in VStack
          VStack(alignment: .leading, spacing: 4) {
            Text("Birthday")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.text01)
            
            if hasSetBirthday {
              Text(formattedBirthday)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.text04)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          
          // Chevron
          Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.appOutline03)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
      }
      .buttonStyle(PlainButtonStyle())
      
      // Add gender Row - Hidden for now
      /*
      Divider()
        .padding(.leading, 56)
      
      accountRow(
        icon: "person.2.fill",
        title: "Add gender",
        value: nil,
        hasChevron: true,
        action: {
          showingGenderView = true
        })
      */
    }
    .background(Color("appSurface02Variant"))
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    .sheet(isPresented: $showingBirthdayView) {
      BirthdayBottomSheet(
        selectedDate: $selectedBirthday,
        onClose: {
          showingBirthdayView = false
        },
        onSave: {
          // Save birthday logic here
          saveBirthday()
        })
    }
    .sheet(isPresented: $showingGenderView) {
      // Placeholder for gender view
      Text("Gender View")
        .navigationTitle("Gender")
    }
  }
  
  // MARK: - Login Information Section
  
  private var loginInformationSection: some View {
    VStack(spacing: 0) {
      // Section Header
      HStack {
        Text("Login Information")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.text01)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 8)
      
      // My social account Row - Custom layout with VStack for title and value
      HStack(spacing: 12) {
        // Icon
        Image(systemName: "apple.logo")
          .font(.system(size: 20))
          .foregroundColor(.appIconColor)
          .frame(width: 24, height: 24)
        
        // Title and Value in VStack
        VStack(alignment: .leading, spacing: 4) {
          Text("My social account")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.text01)
          
          Text(userEmail)
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.text04)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        // Copy button
        Button(action: {
          copyEmail()
        }) {
          Text(copiedEmail ? "Copied" : "Copy")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.primary)
        }
        .buttonStyle(PlainButtonStyle())
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
    }
    .background(Color("appSurface02Variant"))
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
  }
  
  // MARK: - Log Out Button
  
  private var logOutButton: some View {
    HStack {
      Button(action: {
        showingSignOutAlert = true
      }) {
        Text("Sign out")
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.primary)
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 40)
  }
  
  // MARK: - Helper Views
  
  private func accountRow(
    icon: String,
    title: String,
    value: String?,
    hasChevron: Bool = false,
    trailing: AnyView? = nil,
    action: (() -> Void)? = nil
  ) -> some View {
    Button(action: {
      action?()
    }) {
      HStack(spacing: 12) {
        // Icon
        Image(systemName: icon)
          .font(.system(size: 20))
          .foregroundColor(.appIconColor)
          .frame(width: 24, height: 24)
        
        // Title and Value
        HStack(spacing: 8) {
          Text(title)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.text01)
          
          if let value = value {
            Text(value)
              .font(.system(size: 14, weight: .regular))
              .foregroundColor(.text04)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        // Trailing content (Copy button, chevron, etc.)
        if let trailing = trailing {
          trailing
        } else if hasChevron {
          Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.appOutline03)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .contentShape(Rectangle())
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  // MARK: - Helper Properties
  
  private var userDisplayName: String {
    if let user = authManager.currentUser,
       let displayName = user.displayName,
       !displayName.isEmpty
    {
      return displayName
    }
    return "User"
  }
  
  private var userEmail: String {
    if let user = authManager.currentUser,
       let email = user.email
    {
      return email
    }
    return ""
  }
  
  private func loadUserID() {
    Task {
      let currentUser = CurrentUser()
      userID = await currentUser.id
    }
  }
  
  private func copyUserID() {
    UIPasteboard.general.string = userID
    copiedUserID = true
    
    // Reset after 2 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      copiedUserID = false
    }
  }
  
  private func copyEmail() {
    UIPasteboard.general.string = userEmail
    copiedEmail = true
    
    // Reset after 2 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      copiedEmail = false
    }
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
  
  // Data Repair Section
  private var dataRepairSection: some View {
    VStack(spacing: 16) {
      HStack(spacing: 12) {
        Image(systemName: "wrench.and.screwdriver.fill")
          .font(.system(size: 20))
          .foregroundColor(.orange)
        
        VStack(alignment: .leading, spacing: 4) {
          Text("Repair Data")
            .font(.appBodyLarge)
            .fontWeight(.semibold)
            .foregroundColor(.text01)
          
          Text("Recover habits from previous sessions")
            .font(.appBodySmall)
            .foregroundColor(.text03)
        }
        
        Spacer()
        
        if isRepairing {
          ProgressView()
            .scaleEffect(0.8)
        } else {
          Button(action: {
            Task {
              await checkForOrphanedData()
            }
          }) {
            Text("Scan")
              .font(.appBodyMedium)
              .foregroundColor(.orange)
          }
        }
      }
    }
    .padding(20)
    .background(Color.surface)
    .cornerRadius(16)
    .padding(.horizontal, 20)
  }
  
  private func checkForOrphanedData() async {
    do {
      let summary = try await repairService.scanForOrphanedData()
      
      if summary.hasOrphanedData {
        repairMessage = summary.description + "\n\nMigrate this data to your account?"
        showingRepairAlert = true
      } else {
        repairMessage = "No orphaned data found. All your data is already in your account."
        showingRepairAlert = true
      }
    } catch {
      repairError = "Failed to scan for orphaned data: \(error.localizedDescription)"
      showingRepairError = true
    }
  }
  
  private func performDataRepair() async {
    isRepairing = true
    repairError = nil
    
    do {
      let result = try await repairService.migrateAllOrphanedData()
      
      if result.success {
        repairSuccessMessage = result.message
        showingRepairSuccess = true
      } else {
        repairError = result.message
        showingRepairError = true
      }
    } catch {
      repairError = "Failed to repair data: \(error.localizedDescription)"
      showingRepairError = true
    }
    
    isRepairing = false
  }
  
  private func performAccountDeletion() async {
    isDeletingAccount = true
    deletionError = nil
    
    // Check if re-authentication is needed
    let isAuthFresh = await deletionService.checkAuthenticationFreshness()
    if !isAuthFresh {
      await MainActor.run {
        deletionError = "Your authentication session has expired. Please sign out and sign in again, then try deleting your account."
        showingDeletionError = true
        isDeletingAccount = false
      }
      return
    }
    
    do {
      try await deletionService.deleteAccount()
      
      // Mark deletion as successful
      await MainActor.run {
        isDeletingAccount = false
        showingDeletionSuccess = true
      }
      
      // Sign out after successful deletion
      await MainActor.run {
        authManager.signOut()
      }
      
    } catch {
      print("❌ AccountView: Account deletion failed: \(error)")
      
      await MainActor.run {
        deletionError = error.localizedDescription
        showingDeletionError = true
        isDeletingAccount = false
      }
    }
  }
  
  private func requestCameraPermissionAndOpen() {
    if permissionManager.cameraPermissionStatus == .notDetermined {
      permissionManager.requestCameraPermission { granted in
        if granted {
          showingCamera = true
        }
      }
    } else {
      showingCamera = true
    }
  }

  private func requestPhotoLibraryPermissionAndOpen() {
    if permissionManager.photoLibraryPermissionStatus == .notDetermined {
      permissionManager.requestPhotoLibraryPermission { granted in
        if granted {
          showingPhotoLibrary = true
        }
      }
    } else {
      showingPhotoLibrary = true
    }
  }
  
  private func saveBirthday() {
    // Mark that birthday has been set
    hasSetBirthday = true
    // Save birthday logic - can be implemented later (e.g., to UserDefaults or backend)
    print("✅ Birthday saved: \(selectedBirthday)")
    // Optionally save to UserDefaults
    UserDefaults.standard.set(selectedBirthday, forKey: "UserBirthday")
    showingBirthdayView = false
  }
  
  private var formattedBirthday: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy" // e.g., "Dec 16, 2006"
    return formatter.string(from: selectedBirthday)
  }
  
  private func saveName() {
    let newDisplayName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if let user = Auth.auth().currentUser {
      // Update display name using Firebase Auth
      let changeRequest = user.createProfileChangeRequest()
      changeRequest.displayName = newDisplayName.isEmpty ? nil : newDisplayName
      
      changeRequest.commitChanges { error in
        DispatchQueue.main.async {
          if let error = error {
            print("❌ Failed to update name: \(error.localizedDescription)")
          } else {
            // Reload the user to get updated profile information
            user.reload { reloadError in
              DispatchQueue.main.async {
                if let reloadError = reloadError {
                  print("⚠️ Name updated but failed to reload user: \(reloadError.localizedDescription)")
                } else {
                  print("✅ Name updated and user reloaded successfully")
                  
                  // Update authManager's currentUser to reflect the reloaded user
                  if let reloadedUser = Auth.auth().currentUser {
                    authManager.currentUser = reloadedUser
                    print("✅ Updated authManager.currentUser with reloaded user (displayName: \(reloadedUser.displayName ?? "nil"))")
                  }
                }
                showingNameEditSheet = false
              }
            }
          }
        }
      }
    } else {
      // Save for guest user - store in UserDefaults
      UserDefaults.standard.set(newDisplayName, forKey: "GuestName")
      print("✅ Guest name saved: \(newDisplayName)")
      showingNameEditSheet = false
    }
  }
}

// MARK: - BirthdayBottomSheet

struct BirthdayBottomSheet: View {
  @Binding var selectedDate: Date
  let onClose: () -> Void
  let onSave: () -> Void
  
  @State private var selectedMonth: Int
  @State private var selectedDay: Int
  @State private var selectedYear: Int
  
  private let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  private let currentYear = Calendar.current.component(.year, from: Date())
  private let minYear = 1930
  private let maxYear: Int
  
  init(selectedDate: Binding<Date>, onClose: @escaping () -> Void, onSave: @escaping () -> Void) {
    self._selectedDate = selectedDate
    self.onClose = onClose
    self.onSave = onSave
    
    let calendar = Calendar.current
    let today = Date()
    let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
    let selectedComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate.wrappedValue)
    
    let todayYear = todayComponents.year ?? calendar.component(.year, from: today)
    let selectedYear = selectedComponents.year ?? todayYear
    
    // Ensure year is within valid range (1930 to current year), default to current year
    let validYear = (selectedYear >= 1930 && selectedYear <= todayYear) ? selectedYear : todayYear
    
    // Default to current year, month, and day
    self._selectedMonth = State(initialValue: selectedComponents.month ?? todayComponents.month ?? calendar.component(.month, from: today))
    self._selectedDay = State(initialValue: selectedComponents.day ?? todayComponents.day ?? calendar.component(.day, from: today))
    self._selectedYear = State(initialValue: validYear)
    self.maxYear = todayYear
  }
  
  var body: some View {
    BaseBottomSheet(
      title: "Birthday",
      description: "",
      onClose: onClose,
      useGlassCloseButton: true,
      confirmButton: {
        updateSelectedDate()
        onSave()
      },
      confirmButtonTitle: "Done")
    {
      VStack(spacing: 0) {
        // Date Picker with three columns
        HStack(spacing: 0) {
          // Month Picker
          Picker("Month", selection: $selectedMonth) {
            ForEach(1...12, id: \.self) { month in
              Text(months[month - 1])
                .tag(month)
            }
          }
          .pickerStyle(.wheel)
          .frame(maxWidth: .infinity)
          
          // Day Picker
          Picker("Day", selection: $selectedDay) {
            ForEach(1...daysInMonth, id: \.self) { day in
              Text("\(day)")
                .tag(day)
            }
          }
          .pickerStyle(.wheel)
          .frame(maxWidth: .infinity)
          .onChange(of: selectedMonth) { _, _ in
            // Adjust day if it exceeds days in new month
            if selectedDay > daysInMonth {
              selectedDay = daysInMonth
            }
          }
          .onChange(of: selectedYear) { _, _ in
            // Adjust day for leap year changes
            if selectedDay > daysInMonth {
              selectedDay = daysInMonth
            }
          }
          
          // Year Picker
          Picker("Year", selection: $selectedYear) {
            ForEach((minYear...maxYear).reversed(), id: \.self) { year in
              Text(String(year))
                .tag(year)
            }
          }
          .pickerStyle(.wheel)
          .frame(maxWidth: .infinity)
        }
        .frame(height: 200)
        
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
    }
    .presentationDetents([.height(400)])
  }
  
  private var daysInMonth: Int {
    let calendar = Calendar.current
    let dateComponents = DateComponents(year: selectedYear, month: selectedMonth)
    if let date = calendar.date(from: dateComponents),
       let range = calendar.range(of: .day, in: .month, for: date) {
      return range.count
    }
    return 31
  }
  
  private func updateSelectedDate() {
    let calendar = Calendar.current
    var components = DateComponents()
    components.year = selectedYear
    components.month = selectedMonth
    components.day = selectedDay
    
    if let date = calendar.date(from: components) {
      selectedDate = date
    }
  }
}

// MARK: - NameEditBottomSheet

struct NameEditBottomSheet: View {
  @Binding var name: String
  @FocusState.Binding var isFocused: Bool
  let onClose: () -> Void
  let onSave: () -> Void
  
  @State private var originalName: String = ""
  
  private let maxLength = 12
  
  private var hasChanges: Bool {
    name.trimmingCharacters(in: .whitespacesAndNewlines) != originalName.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  var body: some View {
    BaseBottomSheet(
      title: "Name",
      description: "",
      onClose: onClose,
      useGlassCloseButton: true,
      confirmButton: {
        onSave()
      },
      confirmButtonTitle: "Done",
      isConfirmButtonDisabled: !hasChanges)
    {
      VStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          TextField("Enter name", text: $name)
            .font(.appBodyLarge)
            .foregroundColor(.text01)
            .accentColor(.text01)
            .focused($isFocused)
            .submitLabel(.done)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 16)
            .background(Color.surface2)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? .primary : .outline3, lineWidth: isFocused ? 2 : 1.5))
            .cornerRadius(12)
            .onChange(of: name) { oldValue, newValue in
              // Enforce character limit
              if newValue.count > maxLength {
                name = String(newValue.prefix(maxLength))
              }
            }
            .onAppear {
              // Store original name when sheet appears
              originalName = name
              // Focus the field when sheet appears
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
              }
            }
          
          // Character count
          HStack {
            Spacer()
            Text("\(name.count)/\(maxLength)")
              .font(.appLabelSmall)
              .foregroundColor(.text04)
          }
        }
        
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
    }
    .presentationDetents([.height(350)])
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
    iconColor: Color = .appIconColor,
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
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.appOutline03)
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

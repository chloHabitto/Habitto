import StoreKit
import SwiftUI
import FirebaseFirestore
import SwiftData

// MARK: - MoreTabView

struct MoreTabView: View {
  // MARK: Internal

  @ObservedObject var state: HomeViewState
  @EnvironmentObject var themeManager: ThemeManager
  @EnvironmentObject var tutorialManager: TutorialManager
  @EnvironmentObject var authManager: AuthenticationManager
  @EnvironmentObject var vacationManager: VacationManager
  
  // ✅ FIX: Use @Environment to properly observe @Observable changes
  @Environment(XPManager.self) private var xpManager

  var body: some View {
    // 🔍 DEBUG: Log XP value on every body render
    let _ = print("🟣 MoreTabView body render | xpManager.totalXP: \(xpManager.totalXP) | instance: \(ObjectIdentifier(xpManager))")
    
    return WhiteSheetContainer(
      headerContent: {
        AnyView(EmptyView())
      }) {
        // Settings content in main content area with banner and XP card at top
        ScrollView {
          VStack(spacing: 0) {
            // Trial Banner (now scrollable)
            trialBanner
              .entranceAnimation(delay: 0.0)

            // XP Level Display (now scrollable)
            XPLevelDisplay()  // ✅ Gets xpManager from EnvironmentObject
              .id("xp-\(xpManager.totalXP)")  // ✅ Force view recreation when XP changes
              .padding(.bottom, 16)
              .entranceAnimation(delay: 0.05)

            // Settings Sections
            settingsSections
          }
          .padding(.horizontal, 0)
          .padding(.top, 0)
          .padding(.bottom, 20)
        }
      }
      .sheet(isPresented: $showingProfileView) {
        ProfileView()
      }
      .sheet(isPresented: $showingVacationModeSheet) {
        VacationModeSheet()
      }
      .sheet(isPresented: $showingVacationSummary) {
        VacationSummaryView()
      }
      .sheet(isPresented: $showingAboutUs) {
        AboutUsView()
      }
      .sheet(isPresented: $showingFAQ) {
        FAQView()
      }
      .sheet(isPresented: $showingContactUs) {
        ContactUsView()
      }
      .sheet(isPresented: $showingSendFeedback) {
        SendFeedbackView()
      }
      .sheet(isPresented: $showingCustomRating) {
        CustomRatingView()
      }
      .sheet(isPresented: $showingTermsConditions) {
        TermsConditionsView()
      }
      .sheet(isPresented: $showingVacationMode) {
        VacationModeView()
      }
      .sheet(isPresented: $showingSecurity) {
        SecurityView()
      }
      .sheet(isPresented: $showingDataPrivacy) {
        DataPrivacyView()
      }
      .sheet(isPresented: $showingDateCalendar) {
        DateCalendarView()
      }
      .sheet(isPresented: $showingNotifications) {
        NotificationsView()
      }
      .sheet(isPresented: $showingLanguageView) {
        LanguageView()
      }
      .sheet(isPresented: $showingThemeView) {
        ThemeView()
      }
      .sheet(isPresented: $showingNotificationsView) {
        NotificationsView()
      }
      .sheet(isPresented: $showingDataPrivacyView) {
        DataPrivacyView()
      }
      .sheet(isPresented: $showingAccountView) {
        AccountView()
      }
      .sheet(isPresented: $showingPreferencesView) {
        PreferencesView()
      }
      .sheet(isPresented: $showingFAQView) {
        FAQView()
      }
      .sheet(isPresented: $showingTermsConditionsView) {
        TermsConditionsView()
      }
      .sheet(isPresented: $showingAboutUsView) {
        AboutUsView()
      }
      .alert(isPresented: $showingSignOutAlert) {
        Alert(
          title: Text("Sign Out"),
          message: Text("Are you sure you want to sign out?"),
          primaryButton: .destructive(Text("Sign Out")) {
            authManager.signOut()
          },
          secondaryButton: .cancel())
      }
      .onAppear {
        // 🔍 DEBUG: Log XP when tab appears
        print("🟣 MoreTabView.onAppear | XP: \(xpManager.totalXP) | Level: \(xpManager.currentLevel) | instance: \(ObjectIdentifier(xpManager))")
      }
  }

  // MARK: Private

  @State private var showingProfileView = false
  @State private var showingVacationModeSheet = false
  @State private var showingVacationSummary = false
  @State private var showingAboutUs = false
  @State private var showingFAQ = false
  @State private var showingContactUs = false
  @State private var showingSendFeedback = false
  @State private var showingCustomRating = false
  @State private var showingTermsConditions = false
  @State private var showingVacationMode = false
  @State private var showingSecurity = false
  @State private var showingDataPrivacy = false
  @State private var showingDateCalendar = false
  @State private var showingNotifications = false
  @State private var showingLanguageView = false
  @State private var showingThemeView = false
  @State private var showingNotificationsView = false
  @State private var showingDataPrivacyView = false
  @State private var showingAccountView = false
  @State private var showingPreferencesView = false
  @State private var showingFAQView = false
  @State private var showingTermsConditionsView = false
  @State private var showingAboutUsView = false
  @State private var showingSignOutAlert = false

  // MARK: - Trial Banner

  private var trialBanner: some View {
    HStack {
      Text("Start your 7-day Free Trial!")
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.text01)

      Spacer()

      Image(systemName: "chevron.right")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.text01)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.surfaceDim)
    .cornerRadius(8)
    .padding(.horizontal, 20)
    .padding(.top, 20)
    .padding(.bottom, 16)
  }

  // MARK: - Settings Sections

  private var settingsSections: some View {
    VStack(spacing: 0) {
      // General Settings Group
      settingsGroup(
        title: "General Settings",
        items: [
          SettingItem(
            title: "Vacation Mode",
            value: vacationManager.isActive ? "On" : "Off",
            hasChevron: true,
            action: {
              showingVacationMode = true
            }),
          SettingItem(title: "Account", value: nil, hasChevron: true, action: {
            showingAccountView = true
          }),
          // SettingItem(title: "Data & Privacy", value: nil, hasChevron: true, action: {
          //     showingDataPrivacy = true
          // }),
          SettingItem(title: "Date & Calendar", value: nil, hasChevron: true, action: {
            showingDateCalendar = true
          }),
          SettingItem(title: "Notifications", value: nil, hasChevron: true, action: {
            showingNotifications = true
          })
        ])

      // Data Management Group
      settingsGroup(
        title: "Data Management",
        items: [
          SettingItem(title: "Data & Privacy", value: nil, hasChevron: true, action: {
            showingDataPrivacy = true
          })
        ])

      // Support/Legal Group
      settingsGroup(
        title: "Support & Legal",
        items: [
          SettingItem(title: "About us", value: nil, hasChevron: true, action: {
            showingAboutUs = true
          }),
          SettingItem(title: "Tutorial & Tips", value: nil, hasChevron: true, action: {
            // Show tutorial directly instead of resetting it
            tutorialManager.shouldShowTutorial = true
          }),
          SettingItem(title: "FAQ", value: nil, hasChevron: true, action: {
            showingFAQ = true
          }),
          // SettingItem(title: "Contact us", value: nil, hasChevron: true, action: {
          //     showingContactUs = true
          // }) // Hidden for now, can be used in the future
          SettingItem(title: "Send Feedback", value: nil, hasChevron: true, action: {
            showingSendFeedback = true
          }),
          SettingItem(title: "Rate Us", value: nil, hasChevron: true, action: {
            showingCustomRating = true
          }),
          SettingItem(title: "Terms & Conditions", value: nil, hasChevron: true, action: {
            showingTermsConditions = true
          })
        ])

      // ✅ DEBUG: XP Sync Testing Section
      #if DEBUG
      debugXPSyncSection
      #endif
      
      // Version Information
      VStack(spacing: 0) {
        Spacer()

        Text("Habitto v1")
          .font(.system(size: 12, weight: .regular))
          .foregroundColor(.text04)
          .padding(.bottom, 20)
      }
    }
  }

  // MARK: - Debug XP Sync Section
  
  #if DEBUG
  @Environment(\.modelContext) private var modelContext
  @State private var migrationStatus: String = "Checking..."
  @State private var firestoreXP: String = "Loading..."
  @State private var userId: String = "Unknown"
  @State private var isMigrating: Bool = false  // Track migration state
  @State private var showResetAlert: Bool = false  // Show reset confirmation
  
  private var debugXPSyncSection: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("🧪 XP Sync Debug")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.orange)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 12)
      
      // Status Info
      VStack(spacing: 8) {
        debugInfoRow(label: "User ID", value: userId)
        debugInfoRow(label: "Local XP", value: "\(xpManager.totalXP)")
        debugInfoRow(label: "Local Level", value: "\(xpManager.currentLevel)")
        debugInfoRow(label: "Firestore XP", value: firestoreXP)
        debugInfoRow(label: "Migration", value: migrationStatus)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      .background(Color.surfaceDim)
      .cornerRadius(8)
      .padding(.horizontal, 20)
      
      // Action Buttons
      VStack(spacing: 12) {
        HStack(spacing: 12) {
          debugButton(
            title: isMigrating ? "⏳ Migrating..." : "🔄 Migrate XP to Cloud",
            subtitle: isMigrating ? "Please wait, this may take a minute..." : "Upload existing DailyAwards",
            action: {
              if !isMigrating {
                Task {
                  await performMigration()
                }
              }
            }
          )
          .opacity(isMigrating ? 0.6 : 1.0)
          
          if isMigrating {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle())
              .scaleEffect(1.2)
          }
        }
        
        debugButton(
          title: "📊 Check Sync Status",
          subtitle: "Verify Firestore data",
          action: {
            Task {
              await checkSyncStatus()
            }
          }
        )
        
        debugButton(
          title: "🔍 Show Firestore Path",
          subtitle: "Copy path to clipboard",
          action: {
            showFirestorePath()
          }
        )
        
        debugButton(
          title: "🔄 Reset Migration Status",
          subtitle: "After reset, tap 'Migrate XP' button above to run",
          action: {
            Task {
              await resetMigration()
            }
          }
        )
        
        debugButton(
          title: "🔥 Force Load from Firestore",
          subtitle: "Mark migration complete & reload habits",
          action: {
            Task {
              await forceLoadFromFirestore()
            }
          }
        )
        
        debugButton(
          title: "🔧 Fix Missing Baseline/Target",
          subtitle: "Repair breaking habits in Firestore",
          action: {
            Task {
              await fixFirestoreBaseline()
            }
          }
        )
        
        debugButton(
          title: "📊 Audit SwiftData",
          subtitle: "Check CompletionRecords in local storage",
          action: {
            Task {
              await auditSwiftData()
            }
          }
        )
        
        debugButton(
          title: "📊 Audit UserDefaults",
          subtitle: "Check XP and other cached values",
          action: {
            auditUserDefaults()
          }
        )
        
        debugButton(
          title: "📊 Audit Firestore",
          subtitle: "Check what's in cloud storage right now",
          action: {
            Task {
              await auditFirestore()
            }
          }
        )
        
        debugButton(
          title: "📊 Audit Memory",
          subtitle: "Check current in-memory habit state",
          action: {
            auditMemory()
          }
        )
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      
      Rectangle()
        .fill(Color(hex: "F0F0F6"))
        .frame(height: 8)
    }
    .onAppear {
      loadDebugInfo()
      
      // ✅ AUTOMATIC MIGRATION: Trigger XP migration on first app launch
      Task {
        await checkAndRunAutomaticMigration()
      }
    }
    .alert("Migration Reset Complete", isPresented: $showResetAlert) {
      Button("OK") {
        dismissResetAlert()
      }
    } message: {
      Text("Migration status has been reset.\n\nNow tap 'Migrate XP to Cloud' button above to run migration again.")
    }
  }
  
  private func debugInfoRow(label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.text02)
      Spacer()
      Text(value)
        .font(.system(size: 14, weight: .regular))
        .foregroundColor(.text01)
        .lineLimit(1)
        .truncationMode(.middle)
    }
  }
  
  private func debugButton(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.text01)
          Text(subtitle)
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(.text04)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.text04)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(Color.white)
      .cornerRadius(8)
    }
  }
  
  private func loadDebugInfo() {
    userId = AuthenticationManager.shared.currentUser?.uid ?? "Not signed in"
    
    Task {
      await checkSyncStatus()
    }
  }
  
  private func performMigration() async {
    print("🚀 XP_DEBUG: Starting migration...")
    isMigrating = true
    migrationStatus = "Running..."
    
    // ✅ FIX: Yield to let UI update before starting heavy operation
    await Task.yield()
    
    do {
      // Migration will run on main actor but with async Firestore calls
      // that won't block the thread
      try await XPMigrationService.shared.performMigration(modelContext: modelContext)
      migrationStatus = "✅ Complete"
      print("✅ XP_DEBUG: Migration completed successfully")
      
      // Refresh status
      await checkSyncStatus()
    } catch {
      migrationStatus = "❌ Failed: \(error.localizedDescription)"
      print("❌ XP_DEBUG: Migration failed: \(error)")
    }
    
    isMigrating = false
  }
  
  private func checkSyncStatus() async {
    print("🔍 XP_DEBUG: Checking sync status...")
    
    do {
      // Check migration status
      let isComplete = try await FirestoreService.shared.isXPMigrationComplete()
      // ✅ FIX: Only update status if it's not a custom message (like "Running..." or reset message)
      if !migrationStatus.contains("Running") && !migrationStatus.contains("Ready - Tap") {
        migrationStatus = isComplete ? "✅ Complete" : "⏳ Pending"
      }
      print("🔍 XP_DEBUG: Migration complete: \(isComplete)")
      
      // Load Firestore XP
      if let progress = try await FirestoreService.shared.loadUserProgress() {
        firestoreXP = "\(progress.totalXP) (Level \(progress.level))"
        print("🔍 XP_DEBUG: Firestore XP: \(progress.totalXP), Level: \(progress.level)")
      } else {
        firestoreXP = "No data"
        print("🔍 XP_DEBUG: No Firestore data found")
      }
    } catch {
      firestoreXP = "Error: \(error.localizedDescription)"
      print("❌ XP_DEBUG: Failed to load Firestore data: \(error)")
    }
  }
  
  private func showFirestorePath() {
    let uid = AuthenticationManager.shared.currentUser?.uid ?? "{uid}"
    let path = "users/\(uid)/progress/current"
    let url = "https://console.firebase.google.com/project/habittoios/firestore/data/\(path)"
    
    print("📋 XP_DEBUG: Firestore Path:")
    print("   Collection: users/\(uid)/progress")
    print("   Document: current")
    print("   Full URL: \(url)")
    print("")
    print("🔍 To verify in Firestore Console:")
    print("   1. Open: \(url)")
    print("   2. Check fields: totalXP, level, dailyXP")
    print("")
    print("📊 Daily Awards Path:")
    print("   Collection: users/\(uid)/progress/daily_awards/{YYYY-MM}")
    print("   Example: users/\(uid)/progress/daily_awards/2025-10/21")
    
    // Copy to pasteboard if possible
    #if os(iOS)
    UIPasteboard.general.string = url
    print("✅ XP_DEBUG: URL copied to clipboard!")
    #endif
  }
  
  private func fixFirestoreBaseline() async {
    print("🔧 FIX_BASELINE: Scanning Firestore for habits with missing baseline/target...")
    
    guard let userId = AuthenticationManager.shared.currentUser?.uid else {
      print("❌ FIX_BASELINE: No authenticated user")
      return
    }
    
    do {
      let db = Firestore.firestore()
      
      // Fetch ALL habits from Firestore (even invalid ones)
      let snapshot = try await db
        .collection("users")
        .document(userId)
        .collection("habits")
        .getDocuments()
      
      print("🔍 FIX_BASELINE: Found \(snapshot.documents.count) habits in Firestore")
      print("   📋 Document IDs: \(snapshot.documents.map { $0.documentID })")
      
      var fixedCount = 0
      
      for doc in snapshot.documents {
        let data = doc.data()
        let habitType = data["habitType"] as? String ?? ""
        let name = data["name"] as? String ?? "Unknown"
        let baseline = data["baseline"] as? Int ?? -999  // Use -999 to detect missing
        let target = data["target"] as? Int ?? -999
        let isActive = data["isActive"] as? Bool ?? false
        
        print("   - '\(name)' (ID: \(doc.documentID))")
        print("      habitType=\(habitType), baseline=\(baseline), target=\(target), isActive=\(isActive)")
        
        // Fix habits with missing or invalid baseline/target
        if baseline == -999 || target == -999 || (habitType == "breaking" && baseline <= 0) {
          print("   ⚠️ NEEDS FIX: baseline=\(baseline), target=\(target)")
          
          // Extract goal number (e.g., "10 times per day" -> 10)
          if let goalString = data["goal"] as? String {
            let goalNumber = extractNumber(from: goalString) ?? 10
            
            var newBaseline = baseline == -999 ? 0 : baseline
            var newTarget = target == -999 ? goalNumber : target
            
            // For breaking habits: baseline should be current usage, target should be goal
            if habitType == "breaking" {
              newBaseline = goalNumber * 2  // Assume current is 2x the goal
              newTarget = goalNumber
            } else {
              // For formation habits: baseline=0, target=goal amount
              newBaseline = 0
              newTarget = goalNumber
            }
            
            print("   🔧 UPDATING: baseline \(baseline) → \(newBaseline), target \(target) → \(newTarget)")
            
            try await doc.reference.updateData([
              "baseline": newBaseline,
              "target": newTarget
            ])
            
            print("   ✅ FIXED: '\(name)' -> baseline=\(newBaseline), target=\(newTarget)")
            fixedCount += 1
            
            // Verify the update
            let updatedDoc = try await doc.reference.getDocument()
            let updatedData = updatedDoc.data()
            let verifyBaseline = updatedData?["baseline"] as? Int ?? -1
            let verifyTarget = updatedData?["target"] as? Int ?? -1
            print("   ✅ VERIFIED: Firestore now has baseline=\(verifyBaseline), target=\(verifyTarget)")
          }
        } else {
          print("   ✅ OK: No fix needed")
        }
      }
      
      print("✅ FIX_BASELINE: Fixed \(fixedCount) habit(s)")
      
      // Reload habits
      print("🔄 FIX_BASELINE: Reloading habits...")
      await HabitRepository.shared.loadHabits(force: true)
      
      print("✅ FIX_BASELINE: Complete! Habits count: \(HabitRepository.shared.habits.count)")
      for habit in HabitRepository.shared.habits {
        print("   - \(habit.name): baseline=\(habit.baseline), target=\(habit.target)")
      }
      
    } catch {
      print("❌ FIX_BASELINE: Failed - \(error)")
    }
  }
  
  private func extractNumber(from string: String) -> Int? {
    let components = string.components(separatedBy: CharacterSet.decimalDigits.inverted)
    for component in components {
      if let number = Int(component), number > 0 {
        return number
      }
    }
    return nil
  }
  
  private func auditSwiftData() async {
    print("📊 ========== SWIFTDATA AUDIT ==========")
    
    do {
      let context = SwiftDataContainer.shared.modelContext
      
      // Check habits
      let habitDescriptor = FetchDescriptor<HabitData>()
      let habits = try context.fetch(habitDescriptor)
      print("📊 Habits in SwiftData: \(habits.count)")
      for (i, habit) in habits.enumerated() {
        print("   [\(i)] '\(habit.name)' (id: \(habit.id.uuidString.prefix(8)))")
        print("      → completionHistory relationship count: \(habit.completionHistory.count)")
        print("      → difficultyHistory relationship count: \(habit.difficultyHistory.count)")
        print("      → userId: \(habit.userId)")
      }
      
      // Check completion records
      let completionDescriptor = FetchDescriptor<CompletionRecord>()
      let completions = try context.fetch(completionDescriptor)
      print("\n📊 CompletionRecords in SwiftData: \(completions.count)")
      for (i, record) in completions.prefix(20).enumerated() {
        print("   [\(i)] \(record.dateKey): \(record.isCompleted ? "✅ COMPLETE" : "❌ INCOMPLETE")")
        print("      → habitId: \(record.habitId.uuidString.prefix(8))")
        print("      → userId: \(record.userId)")
      }
      
      // Check daily awards
      let awardDescriptor = FetchDescriptor<DailyAward>()
      let awards = try context.fetch(awardDescriptor)
      print("\n📊 DailyAwards in SwiftData: \(awards.count)")
      for (i, award) in awards.enumerated() {
        print("   [\(i)] \(award.dateKey): \(award.xpGranted) XP (allComplete: \(award.allHabitsCompleted))")
        print("      → createdAt: \(award.createdAt)")
        print("      → userId: \(award.userId)")
      }
      
      print("📊 ===================================")
      
    } catch {
      print("❌ SWIFTDATA AUDIT FAILED: \(error)")
    }
  }
  
  private func auditUserDefaults() {
    print("📊 ========== USERDEFAULTS AUDIT ==========")
    
    let dict = UserDefaults.standard.dictionaryRepresentation()
    var foundKeys: [(String, Any)] = []
    
    for (key, value) in dict {
      let keyLower = key.lowercased()
      if keyLower.contains("xp") || keyLower.contains("level") || keyLower.contains("habit") || keyLower.contains("streak") {
        foundKeys.append((key, value))
      }
    }
    
    print("📊 Found \(foundKeys.count) relevant UserDefaults keys:")
    for (key, value) in foundKeys.sorted(by: { $0.0 < $1.0 }) {
      print("   \(key): \(value)")
    }
    
    print("📊 =========================================")
  }
  
  private func auditFirestore() async {
    print("📊 ========== FIRESTORE AUDIT ==========")
    
    guard let userId = AuthenticationManager.shared.currentUser?.uid else {
      print("❌ No authenticated user")
      return
    }
    
    print("📊 User ID: \(userId)")
    
    let db = Firestore.firestore()
    
    do {
      // Check habits collection
      print("\n📊 Fetching habits from Firestore...")
      let habitsSnapshot = try await db.collection("users").document(userId).collection("habits").getDocuments()
      print("📊 Firestore Habits: \(habitsSnapshot.documents.count)")
      
      for (i, doc) in habitsSnapshot.documents.enumerated() {
        let data = doc.data()
        let name = data["name"] as? String ?? "Unknown"
        let completionStatus = data["completionStatus"] as? [String: Bool] ?? [:]
        let completionHistory = data["completionHistory"] as? [String: Int] ?? [:]
        let baseline = data["baseline"] as? Int ?? 0
        let target = data["target"] as? Int ?? 0
        
        print("   [\(i)] '\(name)' (id: \(doc.documentID.prefix(8)))")
        print("      → completionStatus count: \(completionStatus.count)")
        print("      → completionHistory count: \(completionHistory.count)")
        print("      → baseline: \(baseline), target: \(target)")
        
        if !completionStatus.isEmpty {
          print("      → Recent completionStatus entries:")
          for (dateKey, isComplete) in completionStatus.sorted(by: { $0.key > $1.key }).prefix(3) {
            print("         \(dateKey): \(isComplete ? "✅" : "❌")")
          }
        }
        
        if !completionHistory.isEmpty {
          print("      → Recent completionHistory entries:")
          for (dateKey, progress) in completionHistory.sorted(by: { $0.key > $1.key }).prefix(3) {
            print("         \(dateKey): \(progress)")
          }
        }
      }
      
      // Check progress document
      print("\n📊 Fetching progress from Firestore...")
      let progressDoc = try await db.collection("users").document(userId).collection("progress").document("current").getDocument()
      if progressDoc.exists {
        let data = progressDoc.data() ?? [:]
        let totalXP = data["totalXP"] as? Int ?? 0
        let level = data["level"] as? Int ?? 1
        let dailyXP = data["dailyXP"] as? Int ?? 0
        print("📊 Progress:")
        print("   → totalXP: \(totalXP)")
        print("   → level: \(level)")
        print("   → dailyXP: \(dailyXP)")
      } else {
        print("❌ No progress document found")
      }
      
      // Check migration status
      print("\n📊 Checking migration status...")
      let migrationDoc = try await db.collection("users").document(userId).collection("meta").document("migration").getDocument()
      if migrationDoc.exists {
        let data = migrationDoc.data() ?? [:]
        let status = data["status"] as? String ?? "unknown"
        print("📊 Migration status: \(status)")
      } else {
        print("📊 No migration document (not started)")
      }
      
    } catch {
      print("❌ FIRESTORE AUDIT FAILED: \(error)")
    }
    
    print("📊 ===================================")
  }
  
  private func auditMemory() {
    print("📊 ========== MEMORY AUDIT ==========")
    
    let habits = HabitRepository.shared.habits
    print("📊 HabitRepository.habits count: \(habits.count)")
    
    for (i, habit) in habits.enumerated() {
      print("\n   [\(i)] '\(habit.name)' (id: \(habit.id.uuidString.prefix(8)))")
      print("      → habitType: \(habit.habitType.rawValue)")
      print("      → baseline: \(habit.baseline), target: \(habit.target)")
      print("      → syncStatus: \(habit.syncStatus.rawValue)")
      print("      → lastSyncedAt: \(habit.lastSyncedAt?.description ?? "nil")")
      print("      → completionStatus count: \(habit.completionStatus.count)")
      print("      → completionHistory count: \(habit.completionHistory.count)")
      print("      → completionTimestamps count: \(habit.completionTimestamps.count)")
      
      if !habit.completionStatus.isEmpty {
        print("      → Recent completionStatus:")
        for (dateKey, isComplete) in habit.completionStatus.sorted(by: { $0.key > $1.key }).prefix(3) {
          print("         \(dateKey): \(isComplete ? "✅" : "❌")")
        }
      } else {
        print("      → ⚠️ completionStatus is EMPTY!")
      }
      
      if !habit.completionHistory.isEmpty {
        print("      → Recent completionHistory:")
        for (dateKey, progress) in habit.completionHistory.sorted(by: { $0.key > $1.key }).prefix(3) {
          print("         \(dateKey): \(progress)")
        }
      } else {
        print("      → ⚠️ completionHistory is EMPTY!")
      }
    }
    
    print("\n📊 XPManager state:")
    print("   → totalXP: \(xpManager.totalXP)")
    print("   → currentLevel: \(xpManager.currentLevel)")
    print("   → dailyXP: \(xpManager.dailyXP)")
    
    print("\n📊 ===================================")
  }
  
  private func forceLoadFromFirestore() async {
    print("🔥 FORCE_RELOAD: Marking migration complete and reloading from Firestore...")
    
    guard let userId = AuthenticationManager.shared.currentUser?.uid else {
      print("❌ FORCE_RELOAD: No authenticated user")
      return
    }
    
    do {
      // Step 1: Mark migration as complete in Firestore
      let db = Firestore.firestore()
      try await db
        .collection("users")
        .document(userId)
        .collection("meta")
        .document("migration")
        .setData([
          "status": "complete",
          "completedAt": Date(),
          "forcedByUser": true
        ])
      
      print("✅ FORCE_RELOAD: Migration marked as complete")
      migrationStatus = "✅ Complete"
      
      // Step 2: Force reload habits from Firestore
      print("🔥 FORCE_RELOAD: Reloading habits from Firestore...")
      await HabitRepository.shared.loadHabits(force: true)
      
      print("✅ FORCE_RELOAD: Complete! Check if Habit2 is back")
      print("   📊 Current habits count: \(HabitRepository.shared.habits.count)")
      for habit in HabitRepository.shared.habits {
        print("   - \(habit.name) (type: \(habit.habitType), baseline: \(habit.baseline), target: \(habit.target))")
      }
      
    } catch {
      print("❌ FORCE_RELOAD: Failed - \(error)")
    }
  }
  
  private func resetMigration() async {
    print("🔄 XP_DEBUG: Resetting migration status...")
    migrationStatus = "Resetting..."
    
    do {
      // ✅ FIX: Use boolean check instead of storing unused value
      guard AuthenticationManager.shared.currentUser?.uid != nil else {
        print("❌ XP_DEBUG: No authenticated user")
        migrationStatus = "❌ Not authenticated"
        return
      }
      
      // Delete the migration completion marker from Firestore
      // ✅ FIX: Use FirestoreService instead of accessing Firestore directly
      try await FirestoreService.shared.deleteXPMigrationMarker()
      
      migrationStatus = "⏳ Ready - Tap 'Migrate XP' above"
      print("✅ XP_DEBUG: Migration reset successfully!")
      print("   ⚠️ NEXT STEP: Tap 'Migrate XP to Cloud' button above to run migration!")
      
      // ✅ FIX: Don't call checkSyncStatus here - it would overwrite our custom message
      // Just load the Firestore XP to show current state
      if let progress = try? await FirestoreService.shared.loadUserProgress() {
        firestoreXP = "\(progress.totalXP) (Level \(progress.level))"
      }
      
      // Show visual confirmation
      showResetAlert = true
    } catch {
      migrationStatus = "❌ Reset failed"
      print("❌ XP_DEBUG: Reset failed: \(error)")
    }
  }
  
  private func dismissResetAlert() {
    showResetAlert = false
  }
  
  /// ✅ AUTOMATIC MIGRATION: Check if migration is needed and run automatically
  private func checkAndRunAutomaticMigration() async {
    print("🔄 XP_AUTO_MIGRATION: Checking if automatic migration is needed...")
    
    do {
      // Check if migration is already complete
      let isComplete = try await FirestoreService.shared.isXPMigrationComplete()
      
      if isComplete {
        print("ℹ️ XP_AUTO_MIGRATION: Migration already complete, skipping")
        return
      }
      
      print("🚀 XP_AUTO_MIGRATION: Migration needed, starting automatic migration...")
      migrationStatus = "Running (auto)..."
      isMigrating = true
      
      // Run the migration
      try await XPMigrationService.shared.performMigration(modelContext: modelContext)
      
      migrationStatus = "✅ Complete (auto)"
      print("✅ XP_AUTO_MIGRATION: Automatic migration completed successfully!")
      
      // Refresh status
      await checkSyncStatus()
    } catch {
      migrationStatus = "❌ Auto-migration failed"
      print("❌ XP_AUTO_MIGRATION: Automatic migration failed: \(error)")
    }
    
    isMigrating = false
  }
  #endif
  
  // MARK: - Settings Group Helper

  private func settingsGroup(title: String, items: [SettingItem]) -> some View {
    VStack(spacing: 0) {
      ForEach(Array(items.enumerated()), id: \.offset) { index, item in
        HStack(spacing: 12) {
          // Icon based on item type
          if iconForSetting(item.title).hasPrefix("Icon-") {
            // Custom icon
            Image(iconForSetting(item.title))
              .renderingMode(.template)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 24, height: 24)
              .foregroundColor(iconColorForSetting(item.title))
          } else {
            // System icon
            Image(systemName: iconForSetting(item.title))
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(iconColorForSetting(item.title))
              .frame(width: 24, height: 24)
          }

          VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(item.title == "Sign Out" ? .red600 : .text01)
          }

          Spacer()

          HStack(spacing: 4) {
            if let value = item.value {
              Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.text04)
            }

            if item.hasChevron {
              Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.text04)
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
        .onTapGesture {
          if let action = item.action {
            action()
          }
        }

        if index < items.count - 1 {
          Divider()
            .background(Color(.systemGray4))
            .padding(.leading, 56)
        }

        // Add divider after the last item if it's the General Settings group
        // Special case: Add thin divider for Notifications row
        if index == items.count - 1, title == "General Settings", item.title == "Notifications" {
          Divider()
            .background(Color(.systemGray4))
            .padding(.leading, 56)
        }

        // Add divider after the last item if it's the Account & Notifications group
        if index == items.count - 1, title == "Account & Notifications" {
          Rectangle()
            .fill(Color(hex: "F0F0F6"))
            .frame(height: 8)
        }

        // Add divider after the last item if it's the Data Management group
        if index == items.count - 1, title == "Data Management" {
          Rectangle()
            .fill(Color(hex: "F0F0F6"))
            .frame(height: 8)
        }
      }
    }
  }

  // MARK: - Helper Functions

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
  }

  // MARK: - Icon Helpers

  private func iconForSetting(_ title: String) -> String {
    switch title {
    case "Vacation Mode":
      "Icon-Vacation_Filled"
    case "Account":
      "Icon-Profile_Filled"
    case "Data & Privacy":
      "Icon-Cloud_Filled"
    case "Date & Calendar":
      "Icon-Calendar_Filled"
    case "Notifications":
      "Icon-Bell_Filled"
    case "Preferences":
      "Icon-Setting_Filled"
    case "FAQ":
      "Icon-QuestionCircle_Filled"
    case "Contact us":
      "Icon-Letter_Filled"
    case "Send Feedback":
      "Icon-Letter_Filled"
    case "Rate Us":
      "Icon-Hearts_Filled"
    case "Terms & Conditions":
      "Icon-DocumentText_Filled"
    case "About us":
      "Icon-ChatRoundLike_Filled"
    case "Tutorial & Tips":
      "Icon-Notes_Filled"
    case "Time Block Test":
      "clock.fill"
    default:
      "heart"
    }
  }

  private func iconColorForSetting(_: String) -> Color {
    switch themeManager.selectedTheme {
    case .default:
      Color("navy200")
    case .black:
      Color("themeBlack200")
    case .purple:
      Color("themePurple200")
    case .pink:
      Color("themePink200")
    }
  }

  // MARK: - App Rating

  private func requestAppRating() {
    AppRatingManager.shared.requestRating()
  }
}

// MARK: - SettingItem

struct SettingItem {
  // MARK: Lifecycle

  init(title: String, value: String? = nil, hasChevron: Bool = false, action: (() -> Void)? = nil) {
    self.title = title
    self.value = value
    self.hasChevron = hasChevron
    self.action = action
  }

  // MARK: Internal

  let title: String
  let value: String?
  let hasChevron: Bool
  let action: (() -> Void)?
}

#Preview {
  MoreTabView(state: HomeViewState())
    .environmentObject(VacationManager.shared)
    .environmentObject(AuthenticationManager.shared)
    .environmentObject(TutorialManager())
    .environmentObject(ThemeManager.shared)
    .environment(XPManager.shared)
}

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
  
  // Sync status observation
  @ObservedObject var habitRepository = HabitRepository.shared
  
  // iCloud sync status
  @StateObject private var icloudStatus = ICloudStatusManager.shared
  
  // Subscription manager
  @ObservedObject private var subscriptionManager = SubscriptionManager.shared

  var body: some View {
    return WhiteSheetContainer(
      headerContent: {
        AnyView(EmptyView())
      }) {
        // Settings content in main content area with banner and XP card at top
        ScrollView {
          VStack(spacing: 0) {
            // Container for Banner and XP
            VStack(spacing: 20) {
              // Trial Banner (now scrollable) - only show for free users
              // CRITICAL: Use .id() to force view recreation when isPremium changes
              if !subscriptionManager.isPremium {
                trialBanner
                  .id("banner-\(subscriptionManager.isPremium)") // Force recreation when isPremium changes
                  .entranceAnimation(delay: 0.0)
              }

              // XP Level Display (now scrollable)
              XPLevelDisplay()  // ✅ Gets xpManager from EnvironmentObject
                .id("xp-\(xpManager.totalXP)")  // ✅ Force view recreation when XP changes
                .padding(.bottom, 16)
                .entranceAnimation(delay: 0.05)
            }

            // Settings Sections
            settingsSections
          }
          .padding(.horizontal, 0)
          .padding(.top, 20)
          .padding(.bottom, 40) // Increased padding to prevent content from being covered by bottom navigation
        }
        // CRITICAL: Force view to observe isPremium changes by using it in .id()
        .id("moretab-premium-\(subscriptionManager.isPremium)")
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
      .sheet(isPresented: $showingSubscriptionView) {
        SubscriptionView()
      }
      .alert("Data Repair", isPresented: $showingRepairAlert) {
        Button("OK", role: .cancel) { }
      } message: {
        Text(repairMessage)
      }
      #if DEBUG
      .sheet(isPresented: $showingSyncHealth) {
        SyncHealthView()
      }
      .sheet(isPresented: $showingHabitInvestigation) {
        NavigationView {
          HabitInvestigationView()
        }
      }
      .sheet(isPresented: $showingMigrationStatus) {
        MigrationStatusDebugView()
      }
      #endif
      // DISABLED: Sign-in functionality commented out for future use
      /*
      .alert(isPresented: $showingSignOutAlert) {
        Alert(
          title: Text("Sign Out"),
          message: Text("Are you sure you want to sign out?"),
          primaryButton: .destructive(Text("Sign Out")) {
            authManager.signOut()
          },
          secondaryButton: .cancel())
      }
      */
      .task {
        // Check iCloud status when view appears
        await icloudStatus.checkStatus()
      }
      .onAppear {
        // 🔍 DEBUG: Log XP when tab appears
        print("🟣 MoreTabView.onAppear | XP: \(xpManager.totalXP) | Level: \(xpManager.currentLevel) | instance: \(ObjectIdentifier(xpManager))")
      }
      #if DEBUG
      .onChange(of: subscriptionManager.isPremium) { oldValue, newValue in
        if newValue {
          print("🔍 MoreTabView: Hiding free banner - isPremium changed from \(oldValue) to \(newValue)")
        } else {
          print("🔍 MoreTabView: Showing free banner - isPremium changed from \(oldValue) to \(newValue)")
        }
      }
      #endif
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
  @State private var showingMigrationStatus = false
  @State private var showingSubscriptionView = false
  @State private var showingRepairAlert = false
  @State private var repairMessage = ""
  @State private var isRepairing = false
  
  // ✅ DEBUG: Habit Investigation
  #if DEBUG
  @State private var showingHabitInvestigation = false
  @State private var showingSyncHealth = false
  #endif

  // MARK: - Trial Banner

  private var trialBanner: some View {
    Button(action: {
      showingSubscriptionView = true
    }) {
      HStack {
      ZStack {
        Circle()
          .fill(Color(hex: "FCD884").opacity(0.2))
          .frame(width: 92, height: 92)
        
        Circle()
          .fill(Color(hex: "FCD884").opacity(0.3))
          .frame(width: 52, height: 52)
        
        Image("Icon-crown_Filled")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 24, height: 24)
          .foregroundColor(Color(hex: "FFCD02"))
      }
      
      Text("Build better habits with Premium!")
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.text01)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 12)

      Spacer()

      Image(systemName: "chevron.right")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.text01)
    }
    .padding(.leading, -4)
    .padding(.trailing, 16)
    .frame(height: 80)
    .background(Color.surfaceDim)
    .cornerRadius(24)
    .padding(.horizontal, 20)
    .padding(.top, 0)
    .padding(.bottom, 0)
    }
    .buttonStyle(PlainButtonStyle())
  }

  // MARK: - Settings Sections

  private var settingsSections: some View {
    VStack(spacing: 0) {
      // General Settings Group
      settingsGroup(
        title: "General Settings",
        items: [
          SettingItem(
            title: "My subscription",
            value: subscriptionManager.isPremium ? "Premium" : "Free",
            hasChevron: true,
            action: {
              showingSubscriptionView = true
            }),
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
      
      #if DEBUG
      // Debug Section
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

  // MARK: - Debug Section
  
  #if DEBUG
  private var debugXPSyncSection: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("🔍 Debug Tools")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.orange)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 12)
      
      // Essential Debug Buttons
      VStack(spacing: 12) {
        debugButton(
          title: "🔍 Investigate Habits",
          subtitle: "Diagnose habit visibility issues",
          action: {
            showingHabitInvestigation = true
          }
        )
        
        debugButton(
          title: "📊 Audit SwiftData",
          subtitle: "Check local database state",
          action: {
            Task {
              await auditSwiftData()
            }
          }
        )
        
        debugButton(
          title: "📊 Audit Firestore",
          subtitle: "Check cloud sync state",
          action: {
            Task {
              await auditFirestore()
            }
          }
        )
        
        debugButton(
          title: "📊 Audit Memory",
          subtitle: "Check current in-memory state",
          action: {
            auditMemory()
          }
        )
        
        debugButton(
          title: "📈 Sync Health Monitor",
          subtitle: "View sync metrics and health status",
          action: {
            showingSyncHealth = true
          }
        )
        
        // Migration Testing Buttons
        debugButton(
          title: "🔍 Check Migration Status",
          subtitle: "View migration and ProgressEvent status",
          action: {
            Task { @MainActor in
              try? await MigrationTestHelper.shared.printMigrationStatus()
            }
          }
        )
        
        debugButton(
          title: "📋 Migration Status UI",
          subtitle: "Visual migration status dashboard",
          action: {
            showingMigrationStatus = true
          }
        )
        
        debugButton(
          title: "🚀 Trigger Migration (Force)",
          subtitle: "Run migration with force mode",
          action: {
            Task { @MainActor in
              try? await MigrationTestHelper.shared.triggerMigration(force: true)
            }
          }
        )
        
        debugButton(
          title: "🔄 Force Guest Data Migration",
          subtitle: "Re-run complete guest-to-anonymous migration",
          action: {
            Task { @MainActor in
              guard let userId = AuthenticationManager.shared.currentUser?.uid else {
                print("❌ [GUEST_MIGRATION] Cannot force migration: No authenticated user")
                return
              }
              await GuestDataMigrationHelper.forceMigration(userId: userId)
            }
          }
        )
        
        debugButton(
          title: "✅ Verify Migration",
          subtitle: "Check migration results",
          action: {
            Task { @MainActor in
              try? await MigrationTestHelper.shared.printVerification()
            }
          }
        )
        
        // Premium Testing Button
        debugButton(
          title: subscriptionManager.isPremium ? "🔓 Disable Premium (Debug)" : "🔒 Enable Premium (Debug)",
          subtitle: subscriptionManager.isPremium ? "Turn off premium for testing" : "Turn on premium for testing",
          action: {
            if subscriptionManager.isPremium {
              subscriptionManager.disablePremiumForTesting()
            } else {
              subscriptionManager.enablePremiumForTesting()
            }
          }
        )
        
        debugButton(
          title: "🔄 Reset Premium Status",
          subtitle: "Reset to FREE before testing fresh purchase",
          action: {
            subscriptionManager.resetPremiumStatusForDebug()
          }
        )
        
        debugButton(
          title: "🔍 Verify Purchase Status",
          subtitle: "Check all StoreKit transactions and entitlements",
          action: {
            Task {
              await subscriptionManager.verifyPurchaseStatus()
            }
          }
        )
        
        debugButton(
          title: "🔄 Force Sync from Cloud",
          subtitle: "Force StoreKit to check for synced purchases",
          action: {
            Task {
              await subscriptionManager.forceSyncFromCloud()
              
              // Show status after sync
              await MainActor.run {
                let status = subscriptionManager.isPremium ? "Premium" : "Free"
                print("🎉 Sync complete! Status: \(status)")
                print("🔍 MoreTabView sees isPremium: \(subscriptionManager.isPremium)")
              }
            }
          }
        )
        
        debugButton(
          title: "🔍 Verify UI State",
          subtitle: "Check if UI can see subscription state",
          action: {
            subscriptionManager.verifyUIState()
          }
        )
        
        debugButton(
          title: "🔄 Start Periodic Sync Check",
          subtitle: "Check for sync every 30 seconds (auto-stops when found)",
          action: {
            subscriptionManager.startPeriodicSyncCheck(interval: 30)
          }
        )
        
        debugButton(
          title: "⏹️ Stop Periodic Sync Check",
          subtitle: "Stop automatic sync checking",
          action: {
            subscriptionManager.stopPeriodicSyncCheck()
          }
        )
        
        debugButton(
          title: "🧪 Test Event Sourcing",
          subtitle: "Automated test of event creation & XP",
          action: {
            Task { @MainActor in
              try? await MigrationTestHelper.shared.runAutomatedEventSourcingTest()
            }
          }
        )
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      
      Rectangle()
        .fill(Color(hex: "F0F0F6"))
        .frame(height: 8)
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
      print("\n📊 Fetching XP state from Firestore...")
      let progressDoc = try await db.collection("users").document(userId).collection("xp").document("state").getDocument()
      if progressDoc.exists {
        let data = progressDoc.data() ?? [:]
        let totalXP = data["totalXP"] as? Int ?? 0
        let level = data["level"] as? Int ?? 1
        let dailyXP = data["dailyXP"] as? Int ?? 0
        print("📊 XP State:")
        print("   → totalXP: \(totalXP)")
        print("   → level: \(level)")
        print("   → dailyXP: \(dailyXP)")
      } else {
        print("❌ No XP state document found")
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
            Group {
              if item.title == "Sync Status" {
                let isSyncing = habitRepository.syncStatus == .syncing
                // Animated sync icon when syncing
                Image(systemName: iconForSetting(item.title))
                  .font(.system(size: 16, weight: .medium))
                  .foregroundColor(iconColorForSetting(item.title))
                  .frame(width: 24, height: 24)
                  .rotationEffect(.degrees(isSyncing ? 360 : 0))
                  .animation(
                    isSyncing
                      ? Animation.linear(duration: 1.0).repeatForever(autoreverses: false)
                      : .default,
                    value: isSyncing
                  )
              } else {
                Image(systemName: iconForSetting(item.title))
                  .font(.system(size: 16, weight: .medium))
                  .foregroundColor(iconColorForSetting(item.title))
                  .frame(width: 24, height: 24)
              }
            }
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
            
            if let badgeCount = item.badgeCount, badgeCount > 0 {
              Text("\(badgeCount)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red600)
                .clipShape(Capsule())
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

  // MARK: - Sync Status Item
  
  private var syncStatusItem: SettingItem {
    // Use iCloud sync status instead of Firebase sync status
    return SettingItem(
      title: "iCloud Sync",
      value: icloudStatus.statusMessage,
      hasChevron: false,
      badgeCount: nil,
      action: {
        // Refresh iCloud status when tapped
          Task {
          await icloudStatus.checkStatus()
        }
      }
    )
  }
  
  // MARK: - Data Repair
  
  /// Perform manual data repair (XP integrity + CompletionRecord reconciliation)
  private func performDataRepair() {
    guard !isRepairing else { return }
    
    isRepairing = true
    repairMessage = "Repairing data... Please wait."
    showingRepairAlert = true
    
    Task { @MainActor in
      var messages: [String] = []
      
      // 1. XP Integrity Check
      do {
        let awardService = DailyAwardService.shared
        let xpStateBefore = awardService.xpState?.totalXP ?? 0
        
        _ = try await awardService.checkAndRepairIntegrity()
        
        let xpStateAfter = awardService.xpState?.totalXP ?? 0
        
        if xpStateBefore != xpStateAfter {
          messages.append("✅ XP Integrity: Fixed mismatch (\(xpStateBefore) → \(xpStateAfter) XP)")
        } else {
          messages.append("✅ XP Integrity: No issues found")
        }
      } catch {
        messages.append("❌ XP Integrity: Failed - \(error.localizedDescription)")
      }
      
      // 2. CompletionRecord Reconciliation
      do {
        let result = try await DailyAwardService.shared.reconcileCompletionRecords()
        
        if result.mismatchesFixed > 0 {
          messages.append("✅ Completion Records: Fixed \(result.mismatchesFixed) mismatches out of \(result.totalRecords) checked")
        } else {
          messages.append("✅ Completion Records: All \(result.totalRecords) records are consistent")
        }
        
        if result.errors > 0 {
          messages.append("⚠️ Completion Records: \(result.errors) errors encountered")
        }
      } catch {
        messages.append("❌ Completion Records: Failed - \(error.localizedDescription)")
      }
      
      repairMessage = messages.joined(separator: "\n\n")
      isRepairing = false
    }
  }
  
  private func formatLastSyncDate(_ date: Date?) -> String? {
    guard let date = date else { return "Never" }
    
    let now = Date()
    let timeInterval = now.timeIntervalSince(date)
    
    if timeInterval < 60 {
      return "Just now"
    } else if timeInterval < 3600 {
      let minutes = Int(timeInterval / 60)
      return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
    } else if timeInterval < 86400 {
      let hours = Int(timeInterval / 3600)
      return "\(hours) hour\(hours == 1 ? "" : "s") ago"
    } else {
      let days = Int(timeInterval / 86400)
      return "\(days) day\(days == 1 ? "" : "s") ago"
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
    case "My subscription":
      "Icon-crown_Filled"
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
    case "Sync Status":
      "arrow.clockwise"
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

  init(title: String, value: String? = nil, hasChevron: Bool = false, badgeCount: Int? = nil, action: (() -> Void)? = nil) {
    self.title = title
    self.value = value
    self.hasChevron = hasChevron
    self.badgeCount = badgeCount
    self.action = action
  }

  // MARK: Internal

  let title: String
  let value: String?
  let hasChevron: Bool
  let badgeCount: Int?
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

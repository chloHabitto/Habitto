import StoreKit
import SwiftUI
import FirebaseFirestore
import SwiftData
import UIKit

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
      },
      contentBackground: .surface1) {
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
                .padding(.bottom, 24)
                .entranceAnimation(delay: 0.05)
            }

            // Settings Sections
            settingsSections
          }
          .padding(.horizontal, 20)
          .padding(.top, 20)
          .padding(.bottom, 40) // Increased padding to prevent content from being covered by bottom navigation
        }
        // CRITICAL: Force view to observe isPremium changes by using it in .id()
        .id("moretab-premium-\(subscriptionManager.isPremium)")
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
      #if DEBUG
      .onAppear {
        // 🔍 DEBUG: Log XP when tab appears
        print("🟣 MoreTabView.onAppear | XP: \(xpManager.totalXP) | Level: \(xpManager.currentLevel) | instance: \(ObjectIdentifier(xpManager))")
      }
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

  @State private var showingVacationModeSheet = false
  @State private var showingVacationSummary = false
  @State private var showingAboutUs = false
  @State private var showingFAQ = false
  @State private var showingContactUs = false
  @State private var showingSendFeedback = false
  #if DEBUG
  @State private var showDebugTools = false
  #endif
  @State private var showingCustomRating = false
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
    .padding(.top, 0)
    .padding(.bottom, 0)
    }
    .buttonStyle(PlainButtonStyle())
  }

  // MARK: - Settings Sections

  private var settingsSections: some View {
    VStack(spacing: 24) {
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
          SettingItem(title: "Preferences", value: nil, hasChevron: true, action: {
            showingPreferencesView = true
          }),
          // SettingItem(title: "Data & Privacy", value: nil, hasChevron: true, action: {
          //     showingDataPrivacy = true
          // }),
          SettingItem(title: "Date & Calendar", value: nil, hasChevron: true, action: {
            showingDateCalendar = true
          }),
          SettingItem(title: "Notifications", value: nil, hasChevron: true, action: {
            showingNotifications = true
          }),
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
          SettingItem(title: "Privacy Policy", value: nil, hasChevron: true, action: {
            openPrivacyPolicy()
          }),
          SettingItem(title: "Terms of Use", value: nil, hasChevron: true, action: {
            openTermsOfUse()
          })
        ])
      
      #if DEBUG
      // Debug Section - Only visible when enabled via hidden gesture
      if showDebugTools {
        debugXPSyncSection
      }
      #endif
      
      // Version Information
      VStack(spacing: 0) {
        Spacer()

        Text("Habitto v1")
          .font(.system(size: 12, weight: .regular))
          .foregroundColor(.text04)
          .padding(.bottom, 20)
          .onTapGesture(count: 5) {
            #if DEBUG
            showDebugTools.toggle()
            #endif
          }
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
      
      // Essential Debug Buttons Only
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
          title: "📈 Sync Health Monitor",
          subtitle: "View sync metrics and health status",
          action: {
            showingSyncHealth = true
          }
        )
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      
      Rectangle()
        .fill(.surface2)
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
      .background(.surface)
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
  
  #endif
  
  // MARK: - Settings Group Helper

  private func settingsGroup(title: String, items: [SettingItem]) -> some View {
    VStack(spacing: 0) {
      // Section header
      HStack {
        Text(title)
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.text07)
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.bottom, title == "General Settings" || title == "Support & Legal" ? 12 : 16)

      // Options container with rounded background
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
          .background(Color.clear)
          .contentShape(Rectangle())
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
        }
      }
      .background(.surface3)
      .clipShape(RoundedRectangle(cornerRadius: 24))
      .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
    case "Privacy Policy":
      "Icon-DocumentText_Filled"
    case "Terms of Use":
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
    Color.primaryDim
  }

  // MARK: - App Rating

  private func requestAppRating() {
    AppRatingManager.shared.requestRating()
  }
  
  // MARK: - Legal Links
  
  /// Open Privacy Policy in Safari
  private func openPrivacyPolicy() {
    let privacyURL = "https://habittoapp.netlify.app/privacy"
    
    guard let url = URL(string: privacyURL) else {
      print("❌ MoreTabView: Failed to create Privacy Policy URL")
      return
    }
    
    UIApplication.shared.open(url) { success in
      if success {
        print("✅ MoreTabView: Opened Privacy Policy")
      } else {
        print("❌ MoreTabView: Failed to open Privacy Policy URL")
      }
    }
  }
  
  /// Open Apple's standard Terms of Use (EULA) in Safari
  private func openTermsOfUse() {
    let eulaURL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    
    guard let url = URL(string: eulaURL) else {
      print("❌ MoreTabView: Failed to create Terms of Use URL")
      return
    }
    
    UIApplication.shared.open(url) { success in
      if success {
        print("✅ MoreTabView: Opened Apple's standard Terms of Use")
      } else {
        print("❌ MoreTabView: Failed to open Terms of Use URL")
      }
    }
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

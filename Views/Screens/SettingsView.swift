import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
  // MARK: Internal

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var themeManager: ThemeManager

  @State private var showingNotifications = false
  @State private var showingDateCalendar = false
  @State private var showingStreakMode = false
  @State private var showingExportData = false
  @State private var showingBackupRecovery = false
  @State private var showingDeleteData = false

  private var iconColor: Color {
    Color.appIconColor
  }

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          // General Section
          generalSection

          // Customisation Section
          customisationSection

          // Data & Privacy Section
          dataPrivacySection

          Spacer(minLength: 24)
        }
        .padding(.horizontal, 0)
        .padding(.top, 0)
        .padding(.bottom, 20)
        .background(Color("appSurface01Variant02"))
      }
      .background(Color("appSurface01Variant02"))
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "chevron.left")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.text01)
          }
        }
      }
    }
    .preferredColorScheme(themeManager.preferredColorScheme)
    .sheet(isPresented: $showingNotifications) {
      NotificationsView()
    }
    .sheet(isPresented: $showingDateCalendar) {
      DateCalendarView()
    }
    .sheet(isPresented: $showingStreakMode) {
      StreakModeView()
    }
    .sheet(isPresented: $showingExportData) {
      ExportDataView()
    }
    .sheet(isPresented: $showingBackupRecovery) {
      BackupRecoveryView()
    }
    .sheet(isPresented: $showingDeleteData) {
      DeleteDataView()
    }
  }

  // MARK: Private

  private var generalSection: some View {
    VStack(spacing: 0) {
      // Section header
      HStack {
        Text("General")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.text06)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 12)

      // Options container with rounded background
      VStack(spacing: 0) {
        AccountOptionRow(
          icon: "Icon-Bell_Filled",
          title: "Notifications",
          subtitle: "Manage your notification preferences",
          hasChevron: true,
          iconColor: iconColor)
        {
          showingNotifications = true
        }
      }
      .background(Color("appSurface02Variant"))
      .cornerRadius(24)
      .padding(.horizontal, 20)
    }
  }

  private var customisationSection: some View {
    VStack(spacing: 0) {
      // Section header
      HStack {
        Text("Customisation")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.text06)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 12)

      // Options container with rounded background
      VStack(spacing: 0) {
        AccountOptionRow(
          icon: "Icon-Calendar_Filled",
          title: "Date & Calendar",
          subtitle: "Customise date format & calendar",
          hasChevron: true,
          iconColor: iconColor)
        {
          showingDateCalendar = true
        }

        Divider()
          .background(Color(.systemGray4))
          .padding(.leading, 56)

        AccountOptionRow(
          icon: "Icon-flag-filled",
          title: "Streak Mode",
          subtitle: "Define what counts as a completed day",
          hasChevron: true,
          iconColor: iconColor)
        {
          showingStreakMode = true
        }
      }
      .background(Color("appSurface02Variant"))
      .cornerRadius(24)
      .padding(.horizontal, 20)
    }
  }

  private var dataPrivacySection: some View {
    VStack(spacing: 0) {
      // Section header
      HStack {
        Text("Data & Privacy")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.text06)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 12)

      // Options container with rounded background
      VStack(spacing: 0) {
        AccountOptionRow(
          icon: "Icon-Export_Filled",
          title: "Export Data",
          subtitle: "Download your personal data",
          hasChevron: true,
          iconColor: iconColor)
        {
          showingExportData = true
        }

        Divider()
          .background(Color(.systemGray4))
          .padding(.leading, 56)

        AccountOptionRow(
          icon: "Icon-RefreshSquare2_Filled",
          title: "Backup & Recovery",
          subtitle: "Backup and restore your data",
          hasChevron: true,
          iconColor: iconColor)
        {
          showingBackupRecovery = true
        }

        Divider()
          .background(Color(.systemGray4))
          .padding(.leading, 56)

        AccountOptionRow(
          icon: "Icon-TrashBin2_Filled",
          title: "Delete Data",
          subtitle: "Permanently remove your data",
          hasChevron: true,
          iconColor: iconColor)
        {
          showingDeleteData = true
        }
      }
      .background(Color("appSurface02Variant"))
      .cornerRadius(24)
      .padding(.horizontal, 20)
    }
  }
}

#Preview {
  SettingsView()
    .environmentObject(ThemeManager.shared)
}

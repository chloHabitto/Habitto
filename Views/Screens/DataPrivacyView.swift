import SwiftUI

struct DataPrivacyView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Scrollable content
        ScrollView {
          VStack(spacing: 24) {
            // Header with close button and left-aligned title
            ScreenHeader(
              title: "Data & Privacy",
              description: "Manage your data and privacy settings")
            {
              dismiss()
            }

            // Privacy Options
            VStack(spacing: 0) {
              // Data Collection (COMMENTED OUT)
              // VStack(spacing: 0) {
              //    AccountOptionRow(
              //        icon: "Icon-Cloud_Filled",
              //        title: "Data Collection",
              //        subtitle: "Control what data we collect",
              //        hasChevron: true
              //    ) {
              //        // TODO: Implement data collection settings
              //    }
              //
              //    Divider()
              //        .padding(.leading, 56)
              //
              //    AccountOptionRow(
              //        icon: "Icon-ShieldKeyhole_Filled",
              //        title: "Privacy Settings",
              //        subtitle: "Manage your privacy preferences",
              //        hasChevron: true
              //    ) {
              //        // TODO: Implement privacy settings
              //    }
              //
              //    Divider()
              //        .padding(.leading, 56)
              // }

              // Essential Privacy Options
              VStack(spacing: 0) {
                AccountOptionRow(
                  icon: "Icon-Export_Filled",
                  title: "Export Data",
                  subtitle: "Download your personal data",
                  hasChevron: true)
                {
                  showingExportData = true
                }

                Divider()
                  .padding(.leading, 56)

                AccountOptionRow(
                  icon: "Icon-RefreshSquare2_Filled",
                  title: "Backup & Recovery",
                  subtitle: "Backup and restore your data",
                  hasChevron: true)
                {
                  showingBackupRecovery = true
                }

                Divider()
                  .padding(.leading, 56)

                AccountOptionRow(
                  icon: "Icon-TrashBin2_Filled",
                  title: "Delete Data",
                  subtitle: "Permanently remove your data",
                  hasChevron: true)
                {
                  showingDeleteData = true
                }
              }
              .background(Color.surface)
              .cornerRadius(24)
              .padding(.horizontal, 20)
            }
          }
          .padding(.bottom, 24)
        }
        .background(Color.surface2)
      }
      .background(Color.surface2)
    }
    .sheet(isPresented: $showingBackupRecovery) {
      BackupRecoveryView()
    }
    .sheet(isPresented: $showingExportData) {
      ExportDataView()
    }
    .sheet(isPresented: $showingDeleteData) {
      DeleteDataView()
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @State private var showingBackupRecovery = false
  @State private var showingExportData = false
  @State private var showingDeleteData = false
}

#Preview {
  DataPrivacyView()
}

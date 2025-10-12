import SwiftUI

// MARK: - iCloudSyncBanner

/// A banner component that shows the current iCloud sync status
/// Can be displayed at the top of screens to inform users about backup status
struct iCloudSyncBanner: View {
  // MARK: Lifecycle
  
  init(style: BannerStyle = .compact) {
    self.style = style
  }
  
  // MARK: Internal
  
  enum BannerStyle {
    case compact  // Small banner with icon + text
    case detailed // Full banner with explanation and action button
  }
  
  var body: some View {
    Group {
      if !isiCloudAvailable {
        iCloudDisabledBanner
      } else if isGuestMode {
        guestModeBanner
      } else if cloudKitManager.isCloudKitAvailable() {
        if style == .detailed {
          syncActiveBanner
        }
      }
    }
  }
  
  // MARK: Private
  
  private let style: BannerStyle
  
  @StateObject private var cloudKitManager = CloudKitManager.shared
  
  // Check iCloud and auth status
  private var isiCloudAvailable: Bool {
    FileManager.default.ubiquityIdentityToken != nil
  }
  
  private var isGuestMode: Bool {
    AuthenticationManager.shared.currentUser == nil
  }
  
  // Banner variations
  private var iCloudDisabledBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.icloud")
        .foregroundColor(.orange)
        .font(.title3)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("iCloud Backup Disabled")
          .font(.subheadline)
          .fontWeight(.semibold)
        
        if style == .detailed {
          Text("Your habits are saved locally only. Enable iCloud in Settings to backup your data.")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      
      Spacer()
      
      if style == .detailed {
        Button(action: {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
        }) {
          Text("Settings")
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(.orange)
      }
    }
    .padding(style == .compact ? 12 : 16)
    .background(Color.orange.opacity(0.1))
    .cornerRadius(12)
    .padding(.horizontal, style == .compact ? 16 : 0)
  }
  
  private var guestModeBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "person.crop.circle")
        .foregroundColor(.blue)
        .font(.title3)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("Guest Mode")
          .font(.subheadline)
          .fontWeight(.semibold)
        
        if style == .detailed {
          Text("Create an account to backup your habits to iCloud.")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      
      Spacer()
    }
    .padding(style == .compact ? 12 : 16)
    .background(Color.blue.opacity(0.1))
    .cornerRadius(12)
    .padding(.horizontal, style == .compact ? 16 : 0)
  }
  
  private var syncActiveBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "icloud.and.arrow.up")
        .foregroundColor(.green)
        .font(.title3)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("iCloud Backup Active")
          .font(.subheadline)
          .fontWeight(.semibold)
        
        Text("Your habits are syncing to iCloud.")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      Image(systemName: "checkmark.circle.fill")
        .foregroundColor(.green)
    }
    .padding(16)
    .background(Color.green.opacity(0.1))
    .cornerRadius(12)
  }
}

// MARK: - Preview

#Preview("Compact - iCloud Disabled") {
  VStack(spacing: 16) {
    iCloudSyncBanner(style: .compact)
      .preferenceValue(for: iCloudAvailabilityKey.self, value: false)
    
    Spacer()
  }
  .padding()
}

#Preview("Detailed - iCloud Disabled") {
  VStack(spacing: 16) {
    iCloudSyncBanner(style: .detailed)
    
    Spacer()
  }
  .padding()
}

#Preview("Guest Mode") {
  VStack(spacing: 16) {
    iCloudSyncBanner(style: .detailed)
    
    Spacer()
  }
  .padding()
}

// MARK: - Helper PreferenceKey

private struct iCloudAvailabilityKey: PreferenceKey {
  static var defaultValue: Bool = true
  static func reduce(value: inout Bool, nextValue: () -> Bool) {
    value = nextValue()
  }
}

private extension View {
  func preferenceValue(for key: iCloudAvailabilityKey.Type, value: Bool) -> some View {
    self
  }
}


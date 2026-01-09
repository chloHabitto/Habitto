import SwiftUI
import FirebaseAuth

// MARK: - MyDevicesView

struct MyDevicesView: View {
  // MARK: Internal
  
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var subscriptionManager: SubscriptionManager
  @EnvironmentObject var authManager: AuthenticationManager
  
  @State private var devices: [UserDevice] = []
  @State private var isLoading = true
  @State private var errorMessage: String?
  @State private var showingDeviceNameEditSheet = false
  @State private var editedDeviceName: String = ""
  @FocusState private var isDeviceNameFieldFocused: Bool
  @State private var deviceBeingEdited: UserDevice?
  @State private var showingSubscriptionView = false
  @State private var showingDeleteConfirmation = false
  @State private var deviceToDelete: UserDevice?
  
  var body: some View {
    NavigationView {
      ZStack {
        // Background
        Color("appSurface01Variant02")
          .ignoresSafeArea(.all)
        
        if isLoading {
          ProgressView()
            .scaleEffect(1.2)
        } else if let error = errorMessage {
          errorView(error)
        } else if !isAuthenticated {
          guestPromptView
        } else {
          contentView
        }
      }
      .navigationTitle("My devices")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "chevron.left")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.text01)
          }
        }
      }
      .onAppear {
        loadDevices()
      }
      .sheet(isPresented: $showingSubscriptionView) {
        SubscriptionView()
      }
      .sheet(isPresented: $showingDeviceNameEditSheet) {
        DeviceNameEditBottomSheet(
          name: $editedDeviceName,
          isFocused: $isDeviceNameFieldFocused,
          onClose: {
            showingDeviceNameEditSheet = false
            deviceBeingEdited = nil
          },
          onSave: {
            saveDeviceName()
          })
      }
      .alert("Remove Device", isPresented: $showingDeleteConfirmation) {
        Button("Cancel", role: .cancel) {
          deviceToDelete = nil
        }
        Button("Remove", role: .destructive) {
          if let device = deviceToDelete {
            removeDevice(device)
          }
        }
      } message: {
        if let device = deviceToDelete {
          Text("Are you sure you want to remove \"\(device.deviceName)\"? This device will no longer be able to sync.")
        }
      }
    }
  }
  
  // MARK: Private
  
  private var isAuthenticated: Bool {
    guard let currentUser = Auth.auth().currentUser else {
      return false
    }
    return !CurrentUser.isGuestId(currentUser.uid)
  }
  
  private var currentDevice: UserDevice? {
    devices.first { $0.isCurrentDevice }
  }
  
  private var otherDevices: [UserDevice] {
    devices.filter { !$0.isCurrentDevice }
  }
  
  // MARK: - Content Views
  
  private var contentView: some View {
    ScrollView {
      VStack(spacing: 24) {
        // Current device section
        if let current = currentDevice {
          currentDeviceSection(current)
        }
        
        // Other devices section
        otherDevicesSection
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 40)
    }
  }
  
  private func currentDeviceSection(_ device: UserDevice) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Current device")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.text06)
        .padding(.horizontal, 12)
      
      deviceCard(device, isCurrent: true)
    }
  }
  
  private var otherDevicesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Other devices")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.text06)
        .padding(.horizontal, 12)
      
      if !subscriptionManager.isPremium {
        // Premium upsell banner for free users
        premiumUpsellBanner
      } else {
        // List of other devices for premium users
        if otherDevices.isEmpty {
          emptyOtherDevicesView
        } else {
          ForEach(otherDevices) { device in
            deviceCard(device, isCurrent: false)
          }
        }
      }
    }
  }
  
  private func deviceCard(_ device: UserDevice, isCurrent: Bool) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        // Device icon
        Image(systemName: "iphone")
          .font(.system(size: 20, weight: .medium))
          .foregroundColor(.appIconColor)
          .frame(width: 24, height: 24)
        
        VStack(alignment: .leading, spacing: 4) {
          // Display mode
          HStack(spacing: 8) {
            Text(device.deviceName)
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.text01)
            
            if isCurrent {
              Button(action: {
                deviceBeingEdited = device
                editedDeviceName = device.deviceName
                showingDeviceNameEditSheet = true
              }) {
                Image(systemName: "pencil")
                  .font(.system(size: 12, weight: .medium))
                  .foregroundColor(.text04)
              }
            }
          }
          
          Text(device.deviceModel)
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(.text04)
          
          Text("Last login: \(DateUtilities.shared.relativeString(for: device.lastLogin))")
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(.text05)
            .padding(.top, 2)
        }
        
        Spacer()
        
        if !isCurrent && subscriptionManager.isPremium {
          // Delete button for other devices (premium only)
          Button(action: {
            deviceToDelete = device
            showingDeleteConfirmation = true
          }) {
            Image(systemName: "trash")
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(.red600)
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
    }
    .background(.primaryContainer02)
    .clipShape(RoundedRectangle(cornerRadius: 24))
  }
  
  private var premiumUpsellBanner: some View {
    Button(action: {
      showingSubscriptionView = true
    }) {
      HStack(spacing: 12) {
        Image("Icon-crown_Filled")
          .renderingMode(.template)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 24, height: 24)
          .foregroundColor(Color(hex: "FCD884"))
        
        Text("Subscribe to Premium to use multiple devices at once.")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.text01)
          .frame(maxWidth: .infinity, alignment: .leading)
        
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .heavy))
          .foregroundColor(.appOutline03)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .background(Color.green.opacity(0.1))
      .cornerRadius(24)
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  private var emptyOtherDevicesView: some View {
    VStack(spacing: 8) {
      Text("No other devices connected")
        .font(.system(size: 14, weight: .regular))
        .foregroundColor(.text04)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
    .background(.primaryContainer02)
    .clipShape(RoundedRectangle(cornerRadius: 24))
  }
  
  private var guestPromptView: some View {
    VStack(spacing: 16) {
      Image(systemName: "person.circle")
        .font(.system(size: 48))
        .foregroundColor(.text04)
      
      Text("Sign in to see your devices")
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.text01)
      
      Text("Sign in to view and manage your connected devices across all your devices.")
        .font(.system(size: 14, weight: .regular))
        .foregroundColor(.text04)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  
  private func errorView(_ error: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 48))
        .foregroundColor(.red600)
      
      Text("Failed to load devices")
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.text01)
      
      Text(error)
        .font(.system(size: 14, weight: .regular))
        .foregroundColor(.text04)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
      
      Button(action: {
        loadDevices()
      }) {
        Text("Retry")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.white)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
          .background(Color.primary)
          .cornerRadius(12)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  
  // MARK: - Actions
  
  private func loadDevices() {
    guard isAuthenticated else {
      isLoading = false
      return
    }
    
    isLoading = true
    errorMessage = nil
    
    Task {
      do {
        let fetchedDevices = try await DeviceManager.shared.fetchAllDevices()
        await MainActor.run {
          devices = fetchedDevices
          isLoading = false
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          isLoading = false
        }
      }
    }
  }
  
  private func saveDeviceName() {
    guard let device = deviceBeingEdited else { return }
    guard !editedDeviceName.trimmingCharacters(in: .whitespaces).isEmpty else {
      showingDeviceNameEditSheet = false
      deviceBeingEdited = nil
      return
    }
    
    Task {
      do {
        try await DeviceManager.shared.updateDeviceName(editedDeviceName)
        await MainActor.run {
          // Update local state
          if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index].deviceName = editedDeviceName
          }
          showingDeviceNameEditSheet = false
          deviceBeingEdited = nil
        }
      } catch {
        await MainActor.run {
          errorMessage = "Failed to update device name: \(error.localizedDescription)"
          showingDeviceNameEditSheet = false
          deviceBeingEdited = nil
        }
      }
    }
  }
  
  private func removeDevice(_ device: UserDevice) {
    Task {
      do {
        try await DeviceManager.shared.removeDevice(device.id)
        await MainActor.run {
          devices.removeAll { $0.id == device.id }
          deviceToDelete = nil
        }
      } catch {
        await MainActor.run {
          errorMessage = "Failed to remove device: \(error.localizedDescription)"
          deviceToDelete = nil
        }
      }
    }
  }
}

// MARK: - Preview

// MARK: - DeviceNameEditBottomSheet

struct DeviceNameEditBottomSheet: View {
  @Binding var name: String
  @FocusState.Binding var isFocused: Bool
  let onClose: () -> Void
  let onSave: () -> Void
  
  @State private var originalName: String = ""
  
  private let maxLength = 30  // Longer than name (12) since device names can be longer
  
  private var hasChanges: Bool {
    name.trimmingCharacters(in: .whitespacesAndNewlines) != originalName.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  var body: some View {
    BaseBottomSheet(
      title: "Device Name",
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
          TextField("Enter device name", text: $name)
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

// MARK: - Preview

#Preview {
  MyDevicesView()
    .environmentObject(SubscriptionManager.shared)
    .environmentObject(AuthenticationManager.shared)
}

import SwiftUI
import MijickPopups

// MARK: - Example Bottom Popup
struct ExampleBottomPopup: BottomPopup {
    let title: String
    let message: String
    let onConfirm: () -> Void
    
    var body: some View {
        createContent()
    }
    
    func createContent() -> some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text(title)
                    .font(.appHeadlineMedium)
                    .foregroundColor(.text01)
                
                Text(message)
                    .font(.appBodyMedium)
                    .foregroundColor(.text02)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            
            // Buttons
            VStack(spacing: 12) {
                HabittoButton.largeFillPrimary(
                    text: "Confirm",
                    action: {
                        onConfirm()
                        Task { await dismissLastPopup() }
                    }
                )
                
                Button("Cancel") {
                    Task { await dismissLastPopup() }
                }
                .font(.appButtonText1)
                .foregroundColor(.text03)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .background(Color.surface)
    }
    
    func configurePopup(config: BottomPopupConfig) -> BottomPopupConfig {
        config
            .cornerRadius(20)
            .tapOutsideToDismissPopup(true)
    }
}

// MARK: - Example Center Popup (Alert Style)
struct ExampleCenterPopup: CenterPopup {
    let title: String
    let message: String
    let confirmAction: () -> Void
    
    var body: some View {
        createContent()
    }
    
    func createContent() -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.appHeadlineMedium)
                    .foregroundColor(.text01)
                
                Text(message)
                    .font(.appBodyMedium)
                    .foregroundColor(.text02)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    Task { await dismissLastPopup() }
                }
                .font(.appButtonText1)
                .foregroundColor(.text03)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.surfaceContainer)
                .cornerRadius(12)
                
                Button("Confirm") {
                    confirmAction()
                    Task { await dismissLastPopup() }
                }
                .font(.appButtonText1)
                .foregroundColor(.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.primary)
                .cornerRadius(12)
            }
        }
        .padding(24)
        .background(Color.surface)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 4)
    }
    
    func configurePopup(config: CenterPopupConfig) -> CenterPopupConfig {
        config
            .tapOutsideToDismissPopup(true)
    }
}

// MARK: - Example Top Popup (Toast/Banner Style)
struct ExampleTopPopup: TopPopup {
    let message: String
    let icon: String?
    
    var body: some View {
        createContent()
    }
    
    func createContent() -> some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.onSecondary)
            }
            
            Text(message)
                .font(.appBodyMedium)
                .foregroundColor(.onSecondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.secondaryContainer)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
    
    func configurePopup(config: TopPopupConfig) -> TopPopupConfig {
        config
            .tapOutsideToDismissPopup(false)
    }
}

// MARK: - Usage Examples
// To show popups, simply create the popup struct and call .present()
// Example usage in any view:
//
// Button("Show Popup") {
//     ExampleBottomPopup(title: "Hello", message: "World") {
//         print("Confirmed!")
//     }
//     .present()
// }

// MARK: - Test Popup for Debugging
struct TestMijickPopup: CenterPopup {
    init() {
        print("📅 TestMijickPopup: Initializing")
    }
    
    var body: some View {
        createContent()
    }
    
    func createContent() -> some View {
        VStack(spacing: 20) {
            Text("Test Popup")
                .font(.appHeadlineMedium)
                .foregroundColor(.white)
            
            Text("MijickPopups is working!")
                .font(.appBodyMedium)
                .foregroundColor(.white)
            
            Button("Close") {
                print("📅 TestMijickPopup: Close button tapped")
                Task { await dismissLastPopup() }
            }
            .font(.appButtonText1)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
        }
        .padding(24)
        .background(Color.red) // Bright red background to make it obvious
        .onAppear {
            print("📅 TestMijickPopup: onAppear called - popup should be visible")
        }
    }
    
    func configurePopup(config: CenterPopupConfig) -> CenterPopupConfig {
        config
            .cornerRadius(20)
            .tapOutsideToDismissPopup(true)
            .backgroundColor(.black.opacity(0.5)) // Semi-transparent overlay
    }
}

// MARK: - Simple Test Popup for Debugging
struct SimpleTestPopup: CenterPopup {
    init() {
        print("📅 SimpleTestPopup: Initializing")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Simple Test")
                .font(.title)
                .foregroundColor(.white)
            
            Text("MijickPopups is working!")
                .font(.body)
                .foregroundColor(.white)
            
            Button("Close") {
                print("📅 SimpleTestPopup: Close button tapped")
                Task { await dismissLastPopup() }
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
        }
        .padding(30)
        .background(Color.red)
        .cornerRadius(20)
        .onAppear {
            print("📅 SimpleTestPopup: onAppear called - popup should be visible")
        }
    }
    
    func configurePopup(config: CenterPopupConfig) -> CenterPopupConfig {
        config
            .cornerRadius(20)
            .tapOutsideToDismissPopup(true)
            .backgroundColor(.black.opacity(0.5))
    }
}


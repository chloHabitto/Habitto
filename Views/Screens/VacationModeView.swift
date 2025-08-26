import SwiftUI

struct VacationModeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var vacationManager: VacationManager

    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header with close button and left-aligned title
                ScreenHeader(
                    title: "Vacation Mode",
                    description: "Manage your vacation periods and settings"
                ) {
                    dismiss()
                }
                
                // Vacation Mode Toggle Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Vacation Mode")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.text01)
                        }
                        
                        Spacer()
                        
                        // Vacation Mode Toggle
                        Toggle("", isOn: Binding(
                            get: { vacationManager.isActive },
                            set: { isOn in
                                if isOn {
                                    vacationManager.startVacation()
                                } else {
                                    vacationManager.endVacation()
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .primary))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.surface)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                
                // Simple Status Message
                VStack(alignment: .leading, spacing: 16) {
                    Text(vacationManager.isActive ? "Vacation mode is currently active" : "Vacation mode is currently inactive")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text04)
                        .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 24)
            }
        }
        .background(Color.surface2)
        .navigationBarHidden(true)
    }
    

}

#Preview {
    VacationModeView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(VacationManager.shared)
}

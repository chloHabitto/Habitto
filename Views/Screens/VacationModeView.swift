import SwiftUI

struct VacationModeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var vacationManager: VacationManager
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    
    // Computed property to ensure end date is after start date
    private var validEndDate: Date {
        return max(endDate, Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate)
    }

    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // Header with close button and left-aligned title
                ScreenHeader(
                    title: "Vacation Mode",
                    description: "Manage your vacation periods and settings"
                ) {
                    dismiss()
                }
                
                // Vacation Mode Status Section
                VStack(alignment: .leading, spacing: 16) {
                    // Main vacation button at the top
                    if !vacationManager.isActive {
                        // Start Vacation button (blue styling)
                        Button(action: {
                            // Add haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            vacationManager.startVacation(now: startDate)
                        }) {
                            HStack {
                                Image("Icon-Vacation_Filled")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.blue)
                                
                                Text("Start Vacation")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 16)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 0.2), value: vacationManager.isActive)
                    } else {
                        // End Vacation button (red styling)
                        Button(action: {
                            // Add haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                            impactFeedback.impactOccurred()
                            
                            vacationManager.endVacation()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                
                                Text("End Vacation")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.red)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 16)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 0.2), value: vacationManager.isActive)
                    }
                    
                    // Status text below the button
                    VStack(alignment: .leading, spacing: 8) {
                        if vacationManager.isActive {
                            if let currentVacation = vacationManager.current {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Vacation Mode Active")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.blue)
                                    
                                    Text("Started: \(currentVacation.start, formatter: dateFormatter)")
                                        .font(.system(size: 14))
                                        .foregroundColor(.text04)
                                    
                                    if let endDate = currentVacation.end {
                                        Text("Ends: \(endDate, formatter: dateFormatter)")
                                            .font(.system(size: 14))
                                            .foregroundColor(.text04)
                                    }
                                }
                            }
                        } else {
                            Text("Vacation mode is currently inactive")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.text04)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .padding(.top, 16)
                .background(Color.surface)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                // Vacation Settings Section (Date Selection Only)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Vacation Period")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text01)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Start Date")
                                .font(.system(size: 14))
                                .foregroundColor(.text04)
                            
                            Spacer()
                            
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("End Date")
                                .font(.system(size: 14))
                                .foregroundColor(.text04)
                            
                            Spacer()
                            
                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .labelsHidden()
                                .onChange(of: startDate) { _, newStartDate in
                                    // Ensure end date is always after start date
                                    if endDate <= newStartDate {
                                        endDate = Calendar.current.date(byAdding: .day, value: 1, to: newStartDate) ?? newStartDate
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.surface)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                Spacer(minLength: 24)
            }
        }
        .background(Color.surface2)
        .navigationBarHidden(true)
    }
    
    // MARK: - Helper Components
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}


#Preview {
    VacationModeView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(VacationManager.shared)
}

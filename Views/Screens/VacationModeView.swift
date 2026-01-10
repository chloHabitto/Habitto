import SwiftUI

struct VacationModeView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var vacationManager: VacationManager
  @State private var startDate = Date()
  @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

  /// Computed property to ensure end date is after start date
  private var validEndDate: Date {
    max(endDate, Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate)
  }

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Main content with fixed button
        ZStack(alignment: .bottom) {
          ScrollView {
            VStack(alignment: .leading, spacing: 16) {
              // Description text
              Text("Manage your vacation periods and settings")
                .font(.appBodyMedium)
                .foregroundColor(.text05)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
              
              // Travel image
              HStack {
                Spacer()
                Image("Travel")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 120, height: 120)
                Spacer()
              }
              .padding(.top, 20)

              // Vacation Mode Status Section
              if vacationManager.isActive {
                if let currentVacation = vacationManager.current {
                  VStack(alignment: .center, spacing: 16) {
                    // Status text
                    VStack(alignment: .center, spacing: 8) {
                      VStack(alignment: .center, spacing: 8) {
                        HStack(spacing: 4) {
                          Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                          
                          Text("Vacation Mode Active")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                        }

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
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                  }
                  .padding(.top, 16)
                  .background(Color("appSurface02Variant"))
                  .cornerRadius(24)
                  .padding(.horizontal, 20)
                  .frame(maxWidth: .infinity)
                }
              } else {
                Text("Vacation mode is currently inactive")
                  .font(.appTitleMediumEmphasised)
                  .foregroundColor(.text03)
                  .frame(maxWidth: .infinity)
                  .multilineTextAlignment(.center)
                  .padding(.top, 16)
              }

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
                          endDate = Calendar.current
                            .date(byAdding: .day, value: 1, to: newStartDate) ?? newStartDate
                        }
                      }
                  }
                }
              }
              .padding(.horizontal, 20)
              .padding(.vertical, 16)
              .background(Color("appSurface02Variant"))
              .cornerRadius(24)
              .padding(.horizontal, 20)

              Spacer(minLength: 24)
            }
            .padding(.top, 24)
            .padding(.bottom, 140) // Extra bottom padding for fixed button
          }

          // Fixed Vacation button at bottom (changes state based on vacation mode)
          vacationActionButton
        }
      }
      .background(Color("appSurface01Variant02"))
      .navigationTitle("Vacation Mode")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.text01)
          }
        }
      }
    }
  }

  // MARK: - Helper Components

  private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
  }

  // MARK: - Vacation Action Button

  private var vacationActionButton: some View {
    VStack(spacing: 0) {
      // Button container
      HStack {
        if vacationManager.isActive {
          // End Vacation button (custom red200 background, red900 text/icon)
          Button(action: {
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()

            vacationManager.endVacation()
          }) {
            HStack(spacing: 8) {
              Image("Icon-Vacation_Filled")
                .renderingMode(.template)
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundColor(Color("red900"))

              Text("End Vacation")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color("red900"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color("red200"))
            .clipShape(RoundedRectangle(cornerRadius: 28))
          }
        } else {
          // Start Vacation button (primary style)
          HabittoButton(
            size: .large,
            style: .fillPrimary,
            content: .textAndIcon("Start Vacation", "Icon-Vacation_Filled"),
            state: .default,
            action: {
              // Add haptic feedback
              let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
              impactFeedback.impactOccurred()

              vacationManager.startVacation(now: startDate)
            })
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 40)
      .background(Color.surface2)
    }
  }
}

#Preview {
  VacationModeView()
    .environmentObject(AuthenticationManager.shared)
    .environmentObject(VacationManager.shared)
}

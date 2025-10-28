import SwiftUI

/// Debug view to investigate habit storage
struct HabitInvestigationView: View {
  @State private var searchName = "Habit future"
  @State private var output = "Tap 'Investigate' to start..."
  
  var body: some View {
    VStack(spacing: 20) {
      Text("🔍 Habit Storage Investigation")
        .font(.title2)
        .fontWeight(.bold)
        .padding()
      
      // Input field
      VStack(alignment: .leading, spacing: 8) {
        Text("Habit Name to Search:")
          .font(.headline)
        TextField("Enter habit name", text: $searchName)
          .textFieldStyle(.roundedBorder)
          .padding(.horizontal)
      }
      .padding()
      
      // Buttons
      HStack(spacing: 16) {
        Button("Investigate Specific Habit") {
          runInvestigation()
        }
        .buttonStyle(.borderedProminent)
        
        Button("Investigate All Habits") {
          runFullInvestigation()
        }
        .buttonStyle(.bordered)
      }
      
      // Output
      ScrollView {
        Text(output)
          .font(.system(.caption, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
      }
      .background(Color.gray.opacity(0.1))
      .cornerRadius(8)
      .padding()
      
      Spacer()
    }
    .navigationTitle("Habit Investigation")
  }
  
  private func runInvestigation() {
    // Capture console output
    output = "🔍 Investigating '\(searchName)'...\n\n"
    output += "Check the Xcode console for detailed output.\n\n"
    output += "Look for the section that starts with:\n"
    output += "🔍 ════════════════════════════════════════════════════════\n"
    output += "🔍 INVESTIGATION: Looking for '\(searchName)' everywhere...\n"
    
    // Run investigation
    HabitInvestigator.shared.investigate(habitName: searchName)
    
    output += "\n✅ Investigation complete - check Xcode console!"
  }
  
  private func runFullInvestigation() {
    output = "🔍 Running full investigation...\n\n"
    output += "Check the Xcode console for detailed output.\n\n"
    output += "Look for the section that starts with:\n"
    output += "🔍 FULL INVESTIGATION: All habits in all storage locations\n"
    
    // Run full investigation
    HabitInvestigator.shared.investigateAll()
    
    output += "\n✅ Full investigation complete - check Xcode console!"
  }
}

#Preview {
  NavigationView {
    HabitInvestigationView()
  }
}


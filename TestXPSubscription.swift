import SwiftUI

// 🔬 MINIMAL TEST: Add this to your project temporarily

struct TestXPSubscriptionView: View {
  @Environment(XPManager.self) var xpManager
  
  var body: some View {
    let _ = print("🧪 TestXPSubscription re-render | xp:", xpManager.totalXP,
                  "| instance:", ObjectIdentifier(xpManager))
    
    return VStack(spacing: 20) {
      Text("🧪 XP Subscription Test")
        .font(.headline)
      
      // Direct read from @Published property
      Text("XP (direct): \(xpManager.totalXP)")
        .font(.title)
        .foregroundColor(.blue)
      
      // Manual trigger button
      Button("Set XP to 100") {
        xpManager.publishXP(completedDaysCount: 2)
      }
      .buttonStyle(.borderedProminent)
      
      Button("Set XP to 150") {
        xpManager.publishXP(completedDaysCount: 3)
      }
      .buttonStyle(.borderedProminent)
      
      Button("Set XP to 0") {
        xpManager.publishXP(completedDaysCount: 0)
      }
      .buttonStyle(.borderedProminent)
      
      Text("If this view updates when you tap buttons,")
        .font(.caption)
      Text("then the @Observable subscription works!")
        .font(.caption)
        .foregroundColor(.green)
    }
    .padding()
  }
}

// 🔬 Add this to your HomeView.swift in the switch statement:
/*
case .more:
  TestXPSubscriptionView()  // ← Replace MoreTabView temporarily
*/

#Preview {
  TestXPSubscriptionView()
    .environment(XPManager.shared)
}


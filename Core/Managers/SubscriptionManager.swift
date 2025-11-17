import Foundation
import StoreKit

/// Manages subscription status and premium features
@MainActor
class SubscriptionManager: ObservableObject {
  // MARK: - Singleton
  
  static let shared = SubscriptionManager()
  
  // MARK: - Properties
  
  /// Whether the user has an active premium subscription
  @Published var isPremium: Bool = false
  
  /// Maximum number of habits for free users
  static let freeUserHabitLimit = 5
  
  // MARK: - Initialization
  
  private init() {
    // For now, default to false (free user)
    // In the future, this will check StoreKit subscription status
    self.isPremium = false
    loadSubscriptionStatus()
  }
  
  // MARK: - Public Methods
  
  /// Check if user can create more habits
  /// - Parameter currentHabitCount: Current number of habits
  /// - Returns: True if user can create more habits
  func canCreateHabit(currentHabitCount: Int) -> Bool {
    if isPremium {
      return true // Premium users have unlimited habits
    }
    return currentHabitCount < Self.freeUserHabitLimit
  }
  
  /// Check if user has reached the habit limit
  /// - Parameter currentHabitCount: Current number of habits
  /// - Returns: True if user has reached the limit
  func hasReachedHabitLimit(currentHabitCount: Int) -> Bool {
    if isPremium {
      return false // Premium users have unlimited habits
    }
    return currentHabitCount >= Self.freeUserHabitLimit
  }
  
  /// Load subscription status from StoreKit
  private func loadSubscriptionStatus() {
    // TODO: Implement StoreKit subscription checking
    // For now, default to false (free user)
    // This will be implemented when StoreKit integration is added
    Task {
      // Check for active subscriptions
      await checkSubscriptionStatus()
    }
  }
  
  /// Check subscription status using StoreKit
  private func checkSubscriptionStatus() async {
    // TODO: Implement actual StoreKit subscription checking
    // This is a placeholder for future implementation
    // Example:
    // do {
    //   for await result in Transaction.currentEntitlements {
    //     if case .verified(let transaction) = result {
    //       // Check if subscription is active
    //       if transaction.revocationDate == nil {
    //         isPremium = true
    //         return
    //       }
    //     }
    //   }
    //   isPremium = false
    // } catch {
    //   print("Error checking subscription: \(error)")
    //   isPremium = false
    // }
    
    // For now, always return false (free user)
    isPremium = false
  }
  
  /// Update subscription status (call this after purchase)
  func updateSubscriptionStatus(_ isPremium: Bool) {
    self.isPremium = isPremium
  }
  
  /// Restore previous purchases
  /// - Returns: A result indicating success or failure with a message
  func restorePurchases() async -> (success: Bool, message: String) {
    print("🔄 SubscriptionManager: Starting restore purchases...")
    
    // Check for current entitlements (active subscriptions)
    var foundActiveSubscription = false
    
    for await result in Transaction.currentEntitlements {
      if case .verified(let transaction) = result {
        // Check if subscription is still active
        if transaction.revocationDate == nil {
          // Try to get product info (this can throw)
          do {
            let products = try await Product.products(for: [transaction.productID])
            if let product = products.first {
              print("✅ SubscriptionManager: Found active subscription: \(product.id)")
              foundActiveSubscription = true
              
              // Update premium status
              await MainActor.run {
                self.isPremium = true
              }
              
              // Break after finding first active subscription
              break
            }
          } catch {
            // If product lookup fails, continue checking other transactions
            print("⚠️ SubscriptionManager: Failed to get product info for \(transaction.productID): \(error.localizedDescription)")
            continue
          }
        }
      }
    }
    
    if foundActiveSubscription {
      print("✅ SubscriptionManager: Restore successful - active subscription found")
      return (true, "Your subscription has been restored successfully!")
    } else {
      print("ℹ️ SubscriptionManager: No active subscriptions found")
      return (false, "No active subscription found. If you've purchased a subscription, make sure you're signed in with the same Apple ID used for the purchase.")
    }
  }
}


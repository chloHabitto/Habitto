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
  
  /// Product IDs for subscriptions
  enum ProductID {
    static let lifetime = "com.chloe-lee.Habitto.subscription.lifetime"
    static let annual = "com.chloe-lee.Habitto.subscription.annual"
    static let monthly = "com.chloe-lee.Habitto.subscription.monthly"
    
    static var all: [String] {
      [lifetime, annual, monthly]
    }
  }
  
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
    do {
      var hasActiveSubscription = false
      
      // Check for active entitlements (subscriptions and non-consumables)
      for await result in Transaction.currentEntitlements {
        if case .verified(let transaction) = result {
          // Check if it's one of our subscription products
          let productIDs = ProductID.all
          if productIDs.contains(transaction.productID) {
            // Check if subscription is still active (not revoked)
            if transaction.revocationDate == nil {
              print("✅ SubscriptionManager: Found active subscription/product: \(transaction.productID)")
              hasActiveSubscription = true
              break
            }
          }
        }
      }
      
      await MainActor.run {
        self.isPremium = hasActiveSubscription
        if hasActiveSubscription {
          print("✅ SubscriptionManager: Premium status enabled")
        } else {
          print("ℹ️ SubscriptionManager: No active subscription found - free user")
        }
      }
    } catch {
      print("❌ SubscriptionManager: Error checking subscription status: \(error.localizedDescription)")
      await MainActor.run {
        self.isPremium = false
      }
    }
  }
  
  /// Update subscription status (call this after purchase)
  func updateSubscriptionStatus(_ isPremium: Bool) {
    self.isPremium = isPremium
  }
  
  /// Restore previous purchases
  /// - Returns: A result indicating success or failure with a message
  func restorePurchases() async -> (success: Bool, message: String) {
    print("🔄 SubscriptionManager: Starting restore purchases...")
    
    // Re-check subscription status (this will update isPremium)
    await checkSubscriptionStatus()
    
    if isPremium {
      print("✅ SubscriptionManager: Restore successful - active subscription found")
      return (true, "Your subscription has been restored successfully!")
    } else {
      print("ℹ️ SubscriptionManager: No active subscriptions found")
      return (false, "No active subscription found. If you've purchased a subscription, make sure you're signed in with the same Apple ID used for the purchase.")
    }
  }
  
  /// Purchase a subscription product
  /// - Parameter productID: The product ID to purchase
  /// - Returns: A result indicating success or failure with a message
  func purchase(_ productID: String) async -> (success: Bool, message: String) {
    print("🛒 SubscriptionManager: Attempting to purchase: \(productID)")
    
    do {
      // Fetch the product
      let products = try await Product.products(for: [productID])
      guard let product = products.first else {
        return (false, "Product not found. Please try again.")
      }
      
      // Purchase the product
      let result = try await product.purchase()
      
      switch result {
      case .success(let verification):
        // Verify the transaction
        switch verification {
        case .verified(let transaction):
          print("✅ SubscriptionManager: Purchase successful for \(productID)")
          
          // Update premium status
          await checkSubscriptionStatus()
          
          // Finish the transaction
          await transaction.finish()
          
          return (true, "Purchase successful! Premium features are now unlocked.")
          
        case .unverified(_, let error):
          print("⚠️ SubscriptionManager: Unverified transaction: \(error.localizedDescription)")
          return (false, "Purchase could not be verified. Please contact support.")
        }
        
      case .userCancelled:
        print("ℹ️ SubscriptionManager: User cancelled purchase")
        return (false, "Purchase was cancelled.")
        
      case .pending:
        print("⏳ SubscriptionManager: Purchase is pending")
        return (false, "Purchase is pending approval.")
        
      @unknown default:
        print("❓ SubscriptionManager: Unknown purchase result")
        return (false, "An unknown error occurred. Please try again.")
      }
    } catch {
      print("❌ SubscriptionManager: Purchase error: \(error.localizedDescription)")
      return (false, "Purchase failed: \(error.localizedDescription)")
    }
  }
  
  /// Get available subscription products
  /// - Returns: Array of Product objects
  func getAvailableProducts() async -> [Product] {
    do {
      let products = try await Product.products(for: ProductID.all)
      print("✅ SubscriptionManager: Loaded \(products.count) products")
      return products
    } catch {
      print("❌ SubscriptionManager: Failed to load products: \(error.localizedDescription)")
      return []
    }
  }
}


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
}


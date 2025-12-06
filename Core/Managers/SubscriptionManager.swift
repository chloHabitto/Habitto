import Foundation
import StoreKit
import UIKit
import FirebaseAuth

/// Manages subscription status and premium features
@MainActor
class SubscriptionManager: ObservableObject {
  // MARK: - Singleton
  
  static let shared = SubscriptionManager()
  
  // MARK: - Properties
  
  /// Whether the user has an active premium subscription
  @Published var isPremium: Bool = false
  
  /// Transaction listener for cross-device sync
  private var transactionListener: Task<Void, Error>?
  
  #if DEBUG
  /// Periodic sync check timer (DEBUG only - for testing sandbox sync)
  private var syncCheckTimer: Timer?
  #endif
  
  /// Maximum number of habits for free users
  static let freeUserHabitLimit = 5
  
  /// Product IDs for subscriptions
  enum ProductID {
    static let lifetime = "com.chloe_lee.Habitto.subscription.lifetime"
    static let annual = "com.chloe_lee.Habitto.subscription.annual"
    static let monthly = "com.chloe_lee.Habitto.subscription.monthly.v2"
    
    static var all: [String] {
      [lifetime, annual, monthly]
    }
  }
  
  // MARK: - Initialization
  
  private init() {
    print("📱 SubscriptionManager: Initializing...")
    // For now, default to false (free user)
    // In the future, this will check StoreKit subscription status
    self.isPremium = false
    
    // Start transaction listener first (it will check existing transactions)
    startTransactionListener()
    
    // Check subscription status (this runs async)
    loadSubscriptionStatus()
    
    print("📱 SubscriptionManager: Initialized - checking subscription status...")
    
    // Add a delayed check to see final state
    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
      print("📱 SubscriptionManager: 3s after init - isPremium: \(self.isPremium)")
    }
  }
  
  deinit {
    transactionListener?.cancel()
    print("🔔 SubscriptionManager: Transaction listener cancelled")
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
    Task {
      // Check for active subscriptions
      await checkSubscriptionStatus()
      print("📱 SubscriptionManager: Initial subscription check complete - isPremium: \(isPremium)")
    }
  }
  
  /// Start listening for transaction updates (purchases, restores, cross-device syncs)
  private func startTransactionListener() {
    print("🔔 SubscriptionManager: Starting transaction listener for cross-device sync")
    
    // CRITICAL: Use Task.detached because Transaction async sequences MUST run on background thread
    transactionListener = Task.detached { [weak self] in
      guard let self = self else { return }
      
      // FIRST: Check for any existing transactions when listener starts (background thread)
      print("🔔 Transaction Listener: Checking for existing transactions on startup...")
      var existingCount = 0
      for await result in Transaction.currentEntitlements {
        existingCount += 1
        await self.handleTransactionUpdate(result)
      }
      print("🔔 Transaction Listener: Finished checking existing transactions (found \(existingCount))")
      
      // THEN: Continue listening for new transaction updates (background thread)
      print("🔔 Transaction Listener: Now listening for new transaction updates...")
      for await result in Transaction.updates {
        await self.handleTransactionUpdate(result)
      }
    }
  }
  
  /// Handle transaction updates from StoreKit
  /// - Parameter result: The verification result for the transaction
  private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
    guard case .verified(let transaction) = result else {
      print("⚠️ SubscriptionManager: Unverified transaction received")
      return
    }
    
    print("🔔 SubscriptionManager: Transaction update received")
    print("   Product ID: \(transaction.productID)")
    print("   Transaction ID: \(transaction.id)")
    print("   Purchase Date: \(transaction.purchaseDate)")
    
    // Check if this is one of our subscription products
    if ProductID.all.contains(transaction.productID) {
      if transaction.revocationDate == nil {
        print("✅ SubscriptionManager: Active subscription detected - enabling premium")
        
        // Update on MainActor since we're called from Task.detached (background thread)
        await MainActor.run {
          self.isPremium = true
        }
        
        // Finish the transaction to acknowledge receipt
        await transaction.finish()
        
        print("✅ SubscriptionManager: Premium status enabled via transaction listener")
      } else {
        print("⚠️ SubscriptionManager: Transaction was revoked")
        // Update on MainActor since we're called from Task.detached (background thread)
        await MainActor.run {
          self.isPremium = false
        }
        // Finish revoked transactions too to acknowledge we've processed them
        await transaction.finish()
      }
    } else {
      // Finish transactions for other products to prevent StoreKit from resending them
      await transaction.finish()
    }
  }
  
  /// Check subscription status using StoreKit
  private func checkSubscriptionStatus() async {
    print("🔍 SubscriptionManager: Checking subscription status...")
    
    // Check if user is signed into App Store
    #if DEBUG
    print("📱 Device Info:")
    print("   Model: \(UIDevice.current.model)")
    print("   System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
    if let currentUser = Auth.auth().currentUser {
      print("   Firebase User: \(currentUser.uid)")
      print("   Is Anonymous: \(currentUser.isAnonymous)")
    } else {
      print("   Firebase User: Not signed in")
    }
    #endif
    
    // First verify StoreKit can fetch products (basic connectivity check)
    do {
      print("🔍 ============================================")
      print("🔍 STOREKIT PRODUCT FETCH - Detailed Logging")
      print("🔍 ============================================")
      print("🔍 Requesting product IDs:")
      for (index, productID) in ProductID.all.enumerated() {
        print("   \(index + 1). \(productID)")
      }
      print("🔍 Total product IDs requested: \(ProductID.all.count)")
      
      // Detect environment
      #if DEBUG
      print("🔍 Environment: DEBUG (Sandbox)")
      #else
      print("🔍 Environment: RELEASE (Production)")
      #endif
      
      print("🔍 Calling Product.products(for:)...")
      let testProducts = try await Product.products(for: ProductID.all)
      
      print("🔍 ============================================")
      print("🔍 STOREKIT RESPONSE RECEIVED")
      print("🔍 ============================================")
      print("✅ StoreKit connectivity OK")
      print("📊 Products found: \(testProducts.count) / \(ProductID.all.count) requested")
      
      if testProducts.isEmpty {
        print("⚠️ WARNING: StoreKit returned 0 products!")
        print("⚠️ This may indicate:")
        print("   1. StoreKit configuration file not loaded")
        print("   2. Product IDs don't match App Store Connect")
        print("   3. Network connectivity issues")
        print("   4. StoreKit not ready yet")
      } else {
        print("📦 Product Details:")
        for (index, product) in testProducts.enumerated() {
          print("   Product #\(index + 1):")
          print("      ID: \(product.id)")
          print("      Display Name: \(product.displayName)")
          print("      Display Price: \(product.displayPrice)")
          print("      Description: \(product.description)")
          print("      Type: \(product.type)")
          if let subscription = product.subscription {
            print("      Subscription Period: \(formatSubscriptionPeriod(subscription.subscriptionPeriod))")
            print("      Introductory Offer: \(subscription.introductoryOffer != nil ? "Yes" : "No")")
          }
        }
        
        // Check for missing products
        let foundIDs = Set(testProducts.map { $0.id })
        let requestedIDs = Set(ProductID.all)
        let missingIDs = requestedIDs.subtracting(foundIDs)
        
        if !missingIDs.isEmpty {
          print("⚠️ MISSING PRODUCTS (requested but not found):")
          for missingID in missingIDs {
            print("   - \(missingID)")
          }
        }
      }
      print("🔍 ============================================")
    } catch {
      print("❌ ============================================")
      print("❌ STOREKIT ERROR")
      print("❌ ============================================")
      print("❌ StoreKit connectivity FAILED")
      print("❌ Error Type: \(type(of: error))")
      print("❌ Error Description: \(error.localizedDescription)")
      print("❌ Full Error: \(error)")
      
      // Log error details if available
      if let storeKitError = error as? StoreKitError {
        print("❌ StoreKit Error Code: \(storeKitError)")
      }
      
      // Check for underlying errors
      let nsError = error as NSError
      print("❌ NSError Domain: \(nsError.domain)")
      print("❌ NSError Code: \(nsError.code)")
      if !nsError.userInfo.isEmpty {
        print("❌ Error UserInfo:")
        for (key, value) in nsError.userInfo {
          print("   \(key): \(value)")
        }
      }
      
      print("❌ This may indicate:")
      print("   1. Network connectivity issues")
      print("   2. StoreKit not ready")
      print("   3. Invalid product IDs")
      print("   4. App Store Connect configuration issues")
      print("❌ ============================================")
    }
    
    print("🔍 SubscriptionManager: Iterating through Transaction.currentEntitlements...")
    
    var hasActiveSubscription = false
    var checkedCount = 0
    
    // Check for active entitlements (subscriptions and non-consumables)
    for await result in Transaction.currentEntitlements {
      checkedCount += 1
      print("🔍 SubscriptionManager: Checking entitlement #\(checkedCount)")
      
      if case .verified(let transaction) = result {
        print("   ✓ Verified transaction found")
        print("   Product ID: \(transaction.productID)")
        print("   Purchase Date: \(transaction.purchaseDate)")
        print("   Revoked: \(transaction.revocationDate != nil)")
        
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
      } else {
        print("   ⚠️ Unverified transaction (skipped)")
      }
    }
    
    print("🔍 SubscriptionManager: Checked \(checkedCount) entitlement(s)")
    
    // Direct assignment - class is @MainActor so this is already on main thread
    self.isPremium = hasActiveSubscription
    if hasActiveSubscription {
      print("✅ SubscriptionManager: Premium status enabled")
    } else {
      print("ℹ️ SubscriptionManager: No active subscription found - free user")
    }
  }
  
  /// Update subscription status (call this after purchase)
  func updateSubscriptionStatus(_ isPremium: Bool) {
    self.isPremium = isPremium
  }
  
  /// Restore previous purchases
  /// - Returns: A result indicating success or failure with a message
  func restorePurchases() async -> (success: Bool, message: String) {
    print("🔄 ============================================")
    print("🔄 RESTORE PURCHASES - Starting...")
    print("🔄 ============================================")
    print("🔄 Initial isPremium status: \(isPremium)")
    
    print("\n🔄 Step 1: Checking Transaction.currentEntitlements...")
    await checkSubscriptionStatus()
    let isPremiumAfterStep1 = await MainActor.run { self.isPremium }
    print("🔄 After Step 1: isPremium = \(isPremiumAfterStep1)")
    
    print("\n🔄 Step 2: Checking Transaction.all (all transactions, including finished)...")
    var allTransactionCount = 0
    var foundOurProduct = false
    for await result in Transaction.all {
      allTransactionCount += 1
      if case .verified(let transaction) = result {
        print("   Transaction #\(allTransactionCount):")
        print("      Product ID: \(transaction.productID)")
        print("      Transaction ID: \(transaction.id)")
        print("      Purchase Date: \(transaction.purchaseDate)")
        print("      Revoked: \(transaction.revocationDate != nil)")
        
        if ProductID.all.contains(transaction.productID) {
          print("      ✅ Found our product!")
          foundOurProduct = true
          // Process it through the handler to update isPremium
          await handleTransactionUpdate(result)
        } else {
          print("      ℹ️ Not our product (skipping)")
        }
      } else {
        print("   Transaction #\(allTransactionCount): ⚠️ Unverified (skipped)")
      }
    }
    print("🔄 Checked \(allTransactionCount) total transactions")
    let isPremiumAfterStep2 = await MainActor.run { self.isPremium }
    print("🔄 After Step 2: isPremium = \(isPremiumAfterStep2)")
    
    print("\n🔄 Step 3: Final check of Transaction.currentEntitlements...")
    var entitlementCount = 0
    var foundActiveEntitlement = false
    for await result in Transaction.currentEntitlements {
      entitlementCount += 1
      if case .verified(let transaction) = result {
        print("   Entitlement #\(entitlementCount):")
        print("      Product ID: \(transaction.productID)")
        print("      Transaction ID: \(transaction.id)")
        
        if ProductID.all.contains(transaction.productID) {
          print("      ✅ Found active entitlement for our product!")
          foundActiveEntitlement = true
        }
      }
    }
    print("🔄 Found \(entitlementCount) current entitlement(s)")
    
    print("\n🔄 Step 4: Final status check...")
    let finalPremiumStatus = await MainActor.run { self.isPremium }
    print("   Final isPremium: \(finalPremiumStatus)")
    
    // Summary
    print("\n📊 ============================================")
    print("📊 RESTORE SUMMARY")
    print("📊 ============================================")
    print("   Total transactions found: \(allTransactionCount)")
    print("   Our products found: \(foundOurProduct ? "YES" : "NO")")
    print("   Current entitlements: \(entitlementCount)")
    print("   Active entitlement for our product: \(foundActiveEntitlement ? "YES" : "NO")")
    print("   Final isPremium: \(finalPremiumStatus)")
    print("📊 ============================================")
    
    if finalPremiumStatus {
      print("\n✅ ============================================")
      print("✅ RESTORE SUCCESS - Premium enabled!")
      print("✅ ============================================")
      return (true, "Your subscription has been restored successfully!")
    } else {
      print("\n❌ ============================================")
      print("❌ RESTORE FAILED - No purchases found")
      print("❌ ============================================")
      print("ℹ️ This could mean:")
      print("   1. Purchase hasn't synced yet (sandbox can take hours)")
      print("   2. Different Apple ID was used for purchase")
      print("   3. Purchase was made on different app/bundle ID")
      print("   4. Purchase was refunded or expired")
      
      var message = "No active subscription found."
      if allTransactionCount == 0 {
        message += " No transactions found at all. This may indicate a StoreKit sync delay."
      } else if !foundOurProduct {
        message += " Found \(allTransactionCount) transaction(s) but none match your subscription products."
      } else if !foundActiveEntitlement {
        message += " Found transaction but it's not currently active (may be expired or revoked)."
      }
      message += " If you purchased on another device, it may take time to sync. Make sure you're signed in with the same Apple ID."
      
      return (false, message)
    }
  }
  
  /// Force a sync check - useful for debugging
  /// Call this from UI when testing cross-device sync
  func forceSyncCheck() async {
    print("🔄 SubscriptionManager: FORCE SYNC CHECK requested")
    print("🔄 This will re-check StoreKit for any synced purchases...")
    
    await checkSubscriptionStatus()
    
    print("🔄 Force sync check complete")
    print("   Current isPremium status: \(isPremium)")
  }
  
  /// Force StoreKit to sync purchases from other devices
  /// This can help speed up sandbox sync for testing
  func forceSyncFromCloud() async {
    print("🔄 SubscriptionManager: Forcing StoreKit sync check...")
    print("🔄 This will check for synced purchases from other devices")
    print("🔄 Starting isPremium status: \(isPremium)")
    
    // Method 1: Re-check subscription status (checks currentEntitlements)
    print("🔄 Step 1: Re-checking subscription status...")
    await checkSubscriptionStatus()
    let isPremiumAfterStep1 = self.isPremium
    print("🔄 After Step 1: isPremium = \(isPremiumAfterStep1)")
    
    // Method 2: Manually iterate all transactions (forces StoreKit refresh)
    print("🔄 Step 2: Manually checking all transactions...")
    var allTransactionCount = 0
    var foundOurProduct = false
    for await result in Transaction.all {
      allTransactionCount += 1
      if case .verified(let transaction) = result {
        if ProductID.all.contains(transaction.productID) {
          print("✅ Found synced transaction in Transaction.all: \(transaction.productID)")
          foundOurProduct = true
          // Process it through the handler
          await handleTransactionUpdate(result)
        }
      }
    }
    print("🔄 Step 2 complete - found \(allTransactionCount) total transaction(s)")
    let isPremiumAfterStep2 = self.isPremium
    print("🔄 After Step 2: isPremium = \(isPremiumAfterStep2)")
    
    // Method 3: Double-check currentEntitlements after processing
    print("🔄 Step 3: Final check of current entitlements...")
    var entitlementCount = 0
    var foundActiveEntitlement = false
    for await result in Transaction.currentEntitlements {
      entitlementCount += 1
      if case .verified(let transaction) = result {
        if ProductID.all.contains(transaction.productID) {
          print("✅ Found active entitlement: \(transaction.productID)")
          foundOurProduct = true
          foundActiveEntitlement = true
          // Don't call handleTransactionUpdate again - it was already processed in Step 2
        }
      }
    }
    print("🔄 Step 3 complete - found \(entitlementCount) current entitlement(s)")
    let isPremiumAfterStep3 = self.isPremium
    print("🔄 After Step 3: isPremium = \(isPremiumAfterStep3)")
    
    // CRITICAL FIX: If we found entitlements, ensure premium is enabled
    if entitlementCount > 0 && !foundActiveEntitlement {
      // This shouldn't happen, but if we found entitlements, we should have found our product
      print("⚠️ WARNING: Found \(entitlementCount) entitlement(s) but none match our products")
    }
    
    // Final verification: If we found our product OR found active entitlements matching our products, ensure premium is enabled
    if foundOurProduct || foundActiveEntitlement {
      let currentPremiumStatus = self.isPremium
      if !currentPremiumStatus {
        print("⚠️ CRITICAL FIX: Found transaction/entitlement but isPremium is false - forcing true")
        print("⚠️ This indicates something reset isPremium after it was set to true")
        // Direct assignment - class is @MainActor so this is already on main thread
        self.isPremium = true
        print("✅ Premium status forced to true")
      } else {
        print("✅ Premium status already enabled - no fix needed")
      }
      
      print("✅ Synced transaction detected and processed!")
      print("✅ Premium status should now be enabled")
    } else if entitlementCount > 0 {
      // Found entitlements but they don't match our products - this is unusual
      print("⚠️ Found \(entitlementCount) entitlement(s) but none match our product IDs")
      print("⚠️ This might indicate a product ID mismatch")
    } else {
      print("ℹ️ No synced transactions found yet")
      print("ℹ️ Sandbox sync may still be pending (can take 10-30+ minutes)")
      print("ℹ️ Verify:")
      print("   - Same Apple ID on both devices (Settings → App Store)")
      print("   - Same Apple ID in iCloud (Settings → [Your Name])")
      print("   - Both devices connected to internet")
    }
    
    let finalPremiumStatus = self.isPremium
    print("🔄 Force sync complete - Final isPremium status: \(finalPremiumStatus)")
    
    // Summary of state changes
    print("📊 State Change Summary:")
    print("   Step 1 → Step 2: \(isPremiumAfterStep1) → \(isPremiumAfterStep2)")
    print("   Step 2 → Step 3: \(isPremiumAfterStep2) → \(isPremiumAfterStep3)")
    print("   Step 3 → Final: \(isPremiumAfterStep3) → \(finalPremiumStatus)")
    
    // Force UI refresh to ensure all observers are notified
    if foundOurProduct || foundActiveEntitlement {
      // Ensure premium is set
      if !self.isPremium {
        self.isPremium = true
      }
      
      // Explicitly notify all observers (though @Published should handle this)
      self.objectWillChange.send()
      
      print("🔄 Premium status confirmed and UI notified")
      print("   isPremium: \(self.isPremium)")
      print("   UI observers should now see the updated state")
    }
  }
  
  /// Verify subscription state is visible to UI
  func verifyUIState() {
    print("🔍 Verifying UI State:")
    print("   isPremium: \(isPremium)")
    print("   Type: \(type(of: self))")
    print("   Singleton: \(self === SubscriptionManager.shared)")
    
    Task { @MainActor in
      // Since we're in @MainActor context, we're guaranteed to be on the main thread
      print("   On Main Actor: true (guaranteed by @MainActor)")
      print("   isPremium (MainActor): \(self.isPremium)")
      print("   ObjectWillChangePublisher: \(type(of: self.objectWillChange))")
    }
  }
  
  /// Verify current subscription status with detailed logging
  /// Use this on the device that made the purchase
  func verifyPurchaseStatus() async {
    print("🔍 ============================================")
    print("🔍 PURCHASE VERIFICATION - Detailed Check")
    print("🔍 ============================================")
    
    print("\n📱 Device Info:")
    print("   Model: \(UIDevice.current.model)")
    print("   System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
    
    print("\n🎫 Checking ALL transactions (not just current entitlements)...")
    
    // Check ALL transactions (including finished ones)
    var allTransactionCount = 0
    for await result in Transaction.all {
      allTransactionCount += 1
      
      if case .verified(let transaction) = result {
        print("\n   Transaction #\(allTransactionCount):")
        print("   Product ID: \(transaction.productID)")
        print("   Transaction ID: \(transaction.id)")
        print("   Purchase Date: \(transaction.purchaseDate)")
        print("   Revoked: \(transaction.revocationDate != nil)")
        print("   Is Our Product: \(ProductID.all.contains(transaction.productID))")
        
        if ProductID.all.contains(transaction.productID) {
          print("   ⭐ THIS IS A HABITTO SUBSCRIPTION!")
        }
      }
    }
    
    print("\n📊 Total transactions found: \(allTransactionCount)")
    
    print("\n🎫 Checking CURRENT entitlements (active subscriptions)...")
    
    var entitlementCount = 0
    for await result in Transaction.currentEntitlements {
      entitlementCount += 1
      
      if case .verified(let transaction) = result {
        print("\n   Entitlement #\(entitlementCount):")
        print("   Product ID: \(transaction.productID)")
        print("   Transaction ID: \(transaction.id)")
        print("   Purchase Date: \(transaction.purchaseDate)")
        print("   Revoked: \(transaction.revocationDate != nil)")
      }
    }
    
    print("\n📊 Total current entitlements: \(entitlementCount)")
    
    if entitlementCount == 0 {
      print("\n⚠️ WARNING: No current entitlements found!")
      print("   This means:")
      print("   1. Purchase may not have been completed")
      print("   2. Transaction may have been revoked")
      print("   3. Subscription may have expired (if using sandbox tester)")
    }
    
    print("\n💎 Current Premium Status: \(isPremium ? "PREMIUM" : "FREE")")
    print("🔍 ============================================\n")
  }
  
  /// Purchase a subscription product
  /// - Parameter productID: The product ID to purchase
  /// - Returns: A result indicating success or failure with a message
  func purchase(_ productID: String) async -> (success: Bool, message: String) {
    print("🛒 SubscriptionManager: Attempting to purchase: \(productID)")
    
    do {
      // First, try to fetch ALL products to see if StoreKit is working at all
      print("🛒 ============================================")
      print("🛒 PURCHASE FLOW - Product Fetch")
      print("🛒 ============================================")
      print("🛒 Requesting product ID: \(productID)")
      print("🛒 All product IDs being requested:")
      for (index, id) in ProductID.all.enumerated() {
        print("   \(index + 1). \(id)")
      }
      
      // Detect environment
      #if DEBUG
      print("🛒 Environment: DEBUG (Sandbox)")
      #else
      print("🛒 Environment: RELEASE (Production)")
      #endif
      
      print("🛒 Step 1: Fetching all products for connectivity test...")
      let allProducts = try await Product.products(for: ProductID.all)
      
      print("🛒 ============================================")
      print("🛒 ALL PRODUCTS RESPONSE")
      print("🛒 ============================================")
      print("📊 Found \(allProducts.count) / \(ProductID.all.count) total product(s)")
      
      if allProducts.isEmpty {
        print("⚠️ WARNING: StoreKit returned 0 products!")
        print("⚠️ This means StoreKit configuration is NOT loaded or product IDs don't match.")
        print("⚠️ Verify:")
        print("   1. Scheme → Run → Options → StoreKit Configuration File is set")
        print("   2. File is in Xcode project with correct target membership")
        print("   3. Product IDs match App Store Connect exactly")
        print("   4. Clean build folder and restart Xcode")
        print("   5. Testing on iOS 15+ simulator/device")
      } else {
        print("✅ StoreKit is working! Available products:")
        for (index, product) in allProducts.enumerated() {
          print("   Product #\(index + 1):")
          print("      ID: \(product.id)")
          print("      Display Name: \(product.displayName)")
          print("      Display Price: \(product.displayPrice)")
          print("      Type: \(product.type)")
        }
      }
      
      // Fetch the specific product
      print("🛒 Step 2: Fetching specific product: \(productID)...")
      let products = try await Product.products(for: [productID])
      
      print("🛒 ============================================")
      print("🛒 SPECIFIC PRODUCT RESPONSE")
      print("🛒 ============================================")
      print("📊 Fetched \(products.count) product(s) for \(productID)")
      
      guard let product = products.first else {
        print("❌ Product '\(productID)' not found in StoreKit.")
        print("❌ Available product IDs from previous fetch: \(allProducts.map { $0.id })")
        print("❌ Requested product ID: \(productID)")
        print("❌ This indicates a product ID mismatch or StoreKit configuration issue")
        return (false, "Product not found. Please make sure StoreKit configuration is set up in Xcode.")
      }
      
      print("✅ Product found:")
      print("   ID: \(product.id)")
      print("   Display Name: \(product.displayName)")
      print("   Display Price: \(product.displayPrice)")
      print("   Description: \(product.description)")
      if let subscription = product.subscription {
        print("   Subscription Period: \(formatSubscriptionPeriod(subscription.subscriptionPeriod))")
      }
      print("🛒 ============================================")
      
      // Purchase the product
      print("🛒 SubscriptionManager: Initiating purchase...")
      let result = try await product.purchase()
      print("🛒 SubscriptionManager: Purchase result received")
      
      switch result {
      case .success(let verification):
        // Verify the transaction
        switch verification {
        case .verified(let transaction):
          print("✅ SubscriptionManager: Purchase successful for \(productID)")
          
          // Finish the transaction FIRST
          await transaction.finish()
          print("✅ SubscriptionManager: Transaction finished - ID: \(transaction.id)")
          print("   Product ID: \(transaction.productID)")
          
          // Small delay to let StoreKit process
          try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
          
          // VERIFY the transaction is now in currentEntitlements
          print("🔍 Verifying transaction was recorded in StoreKit...")
          var foundInEntitlements = false
          for await result in Transaction.currentEntitlements {
            if case .verified(let entitlement) = result,
               entitlement.productID == productID {
              foundInEntitlements = true
              print("✅ VERIFIED: Transaction found in currentEntitlements")
              print("   Entitlement Transaction ID: \(entitlement.id)")
              break
            }
          }
          
          if !foundInEntitlements {
            print("⚠️ WARNING: Transaction NOT found in currentEntitlements after purchase!")
            print("⚠️ This indicates a StoreKit issue - purchase may not persist")
            print("⚠️ Premium status will NOT be enabled until transaction appears in entitlements")
          }
          
          // Only set premium if verified
          if foundInEntitlements {
            // Direct assignment - class is @MainActor so this is already on main thread
            self.isPremium = true
            print("✅ SubscriptionManager: Premium status enabled (verified in StoreKit)")
            
            return (true, "Purchase successful! Premium features are now unlocked.")
          } else {
            // Transaction not found - don't set premium
            print("❌ SubscriptionManager: Purchase completed but verification failed")
            print("❌ Transaction not found in currentEntitlements - this is unusual")
            print("❌ Please try restarting the app or contact support")
            
            // Re-check subscription status to see if it appears later
            await checkSubscriptionStatus()
            
            return (false, "Purchase completed but verification failed. Please restart the app or try restoring purchases.")
          }
          
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
      print("❌ SubscriptionManager: Purchase error occurred")
      print("❌ SubscriptionManager: Error type: \(type(of: error))")
      print("❌ SubscriptionManager: Error description: \(error.localizedDescription)")
      print("❌ SubscriptionManager: Full error: \(error)")
      return (false, "Purchase failed: \(error.localizedDescription)")
    }
  }
  
  /// Get available subscription products
  /// - Returns: Array of Product objects
  func getAvailableProducts() async -> [Product] {
    print("🔍 ============================================")
    print("🔍 GET AVAILABLE PRODUCTS - Detailed Logging")
    print("🔍 ============================================")
    print("🔍 Requesting product IDs:")
    for (index, productID) in ProductID.all.enumerated() {
      print("   \(index + 1). \(productID)")
    }
    
    // Detect environment
    #if DEBUG
    print("🔍 Environment: DEBUG (Sandbox)")
    #else
    print("🔍 Environment: RELEASE (Production)")
    #endif
    
    do {
      print("🔍 Calling Product.products(for:)...")
      let products = try await Product.products(for: ProductID.all)
      
      print("🔍 ============================================")
      print("🔍 PRODUCTS RESPONSE")
      print("🔍 ============================================")
      print("✅ Loaded \(products.count) / \(ProductID.all.count) requested products")
      
      if products.isEmpty {
        print("⚠️ WARNING: No products returned!")
        print("⚠️ This may indicate:")
        print("   1. StoreKit configuration not loaded")
        print("   2. Product IDs don't match App Store Connect")
        print("   3. Network issues")
      } else {
        print("📦 Product Details:")
        for (index, product) in products.enumerated() {
          print("   Product #\(index + 1):")
          print("      ID: \(product.id)")
          print("      Display Name: \(product.displayName)")
          print("      Display Price: \(product.displayPrice)")
          print("      Description: \(product.description)")
          print("      Type: \(product.type)")
          if let subscription = product.subscription {
            print("      Subscription Period: \(formatSubscriptionPeriod(subscription.subscriptionPeriod))")
          }
        }
        
        // Check for missing products
        let foundIDs = Set(products.map { $0.id })
        let requestedIDs = Set(ProductID.all)
        let missingIDs = requestedIDs.subtracting(foundIDs)
        
        if !missingIDs.isEmpty {
          print("⚠️ MISSING PRODUCTS:")
          for missingID in missingIDs {
            print("   - \(missingID)")
          }
        }
      }
      print("🔍 ============================================")
      
      return products
    } catch {
      print("❌ ============================================")
      print("❌ GET PRODUCTS ERROR")
      print("❌ ============================================")
      print("❌ Failed to load products")
      print("❌ Error Type: \(type(of: error))")
      print("❌ Error Description: \(error.localizedDescription)")
      print("❌ Full Error: \(error)")
      
      // Log error details if available
      let nsError = error as NSError
      print("❌ NSError Domain: \(nsError.domain)")
      print("❌ NSError Code: \(nsError.code)")
      if !nsError.userInfo.isEmpty {
        print("❌ Error UserInfo:")
        for (key, value) in nsError.userInfo {
          print("   \(key): \(value)")
        }
      }
      print("❌ ============================================")
      
      return []
    }
  }
  
  // MARK: - Debug Methods (Remove before release)
  
  #if DEBUG
  /// Temporary debug method to enable premium for testing
  /// ⚠️ REMOVE THIS BEFORE RELEASE
  func enablePremiumForTesting() {
    print("🧪 SubscriptionManager: DEBUG - Manually enabling premium for testing")
    self.isPremium = true
    print("✅ SubscriptionManager: Premium enabled (DEBUG MODE)")
  }
  
  /// Temporary debug method to disable premium for testing
  /// ⚠️ REMOVE THIS BEFORE RELEASE
  func disablePremiumForTesting() {
    print("🧪 SubscriptionManager: DEBUG - Manually disabling premium for testing")
    self.isPremium = false
    print("ℹ️ SubscriptionManager: Premium disabled (DEBUG MODE)")
  }
  
  /// Force enable premium for debugging (independent of StoreKit)
  func forceEnablePremiumForDebug() {
    print("🧪 DEBUG: Forcing premium status for testing")
    self.isPremium = true
    print("✅ DEBUG: Premium status forced to true")
  }
  
  /// Reset premium status to FREE for debugging
  /// Use this before testing a fresh purchase
  func resetPremiumStatusForDebug() {
    print("🔄 DEBUG: Resetting premium status to FREE")
    print("🔄 This will allow testing a fresh purchase")
    self.isPremium = false
    print("✅ Premium status reset to: \(isPremium)")
    print("ℹ️ Note: This only resets the in-memory status.")
    print("ℹ️ If you have a real StoreKit purchase, it will be restored on next check.")
  }
  
  /// Start periodic sync checking (DEBUG ONLY - for testing sandbox sync)
  /// This will check for synced purchases every N seconds
  func startPeriodicSyncCheck(interval: TimeInterval = 30) {
    print("🔄 Starting periodic sync check (every \(interval) seconds)")
    
    syncCheckTimer?.invalidate()
    syncCheckTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        print("🔄 Periodic sync check...")
        await self?.checkSubscriptionStatus()
        if let isPremium = self?.isPremium, isPremium {
          print("✅ Periodic check: Premium status detected! Stopping periodic checks.")
          self?.stopPeriodicSyncCheck()
        }
      }
    }
  }
  
  /// Stop periodic sync checking
  func stopPeriodicSyncCheck() {
    syncCheckTimer?.invalidate()
    syncCheckTimer = nil
    print("⏹️ Stopped periodic sync check")
  }
  #endif
  
  // MARK: - Helper Methods
  
  /// Format subscription period for logging
  private func formatSubscriptionPeriod(_ period: Product.SubscriptionPeriod) -> String {
    let unit: String
    switch period.unit {
    case .day:
      unit = "day"
    case .week:
      unit = "week"
    case .month:
      unit = "month"
    case .year:
      unit = "year"
    @unknown default:
      unit = "unknown"
    }
    return "\(period.value) \(unit)\(period.value == 1 ? "" : "s")"
  }
}


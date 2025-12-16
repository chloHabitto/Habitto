import SwiftUI
import Combine
import UIKit
import StoreKit

// MARK: - SubscriptionView

struct SubscriptionView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      ZStack(alignment: .bottom) {
        // Background - use semantic color for light/dark mode
        Color.surface2
          .ignoresSafeArea(.all)
        
        ScrollView {
          VStack(spacing: 0) {
            // Crown icon
            Image("Icon-crown_Filled")
              .renderingMode(.template)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 32, height: 32)
              .foregroundColor(.primary)
              .padding(.top, 20)
              .padding(.bottom, 12)
            
            // Header text (smaller)
            headerText
              .padding(.bottom, 24)
            
            // Comparison table / Features (Benefits)
            comparisonTable
              .padding(.bottom, 32)
            
            // Review carousel
            reviewCarousel
              .padding(.bottom, 32)
            
            // Subscription options (moved from sheet)
            subscriptionOptions
              .padding(.bottom, 24)
            
            // Legal links (Privacy Policy and Terms of Use)
            mainLegalLinks
              .padding(.bottom, 16)
            
            // Subscription terms
            subscriptionTerms
              .padding(.bottom, 40)
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 120) // Padding to prevent content from being covered by bottom buttons
        }
        
        // Call-to-action buttons at bottom
        VStack(spacing: 12) {
          ctaButton
          restorePurchaseButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
          VStack(spacing: 0) {
            // Gradient background starting from top (80pt total, including 16pt top padding)
            LinearGradient(
              gradient: Gradient(colors: [
                Color.surface2.opacity(0),
                Color.surface2.opacity(0.8)
              ]),
              startPoint: .top,
              endPoint: .bottom
            )
            .frame(height: 80)
            
            // Solid background extending to bottom
            Color.surface2.opacity(0.8)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .padding(.top, 16)
          .ignoresSafeArea(.container, edges: .bottom)
        )
      }
      .navigationTitle("")
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
      .sheet(isPresented: $showingTermsConditions) {
        TermsConditionsView(initialTab: selectedLegalTab)
      }
      .alert("Restore Purchase", isPresented: $showingRestoreAlert) {
        Button("OK", role: .cancel) {
          restoreMessage = nil
        }
      } message: {
        if let message = restoreMessage {
          Text(message)
        }
      }
      .alert("Purchase", isPresented: $showingPurchaseAlert) {
        Button("OK", role: .cancel) {
          purchaseMessage = nil
        }
      } message: {
        if let message = purchaseMessage {
          Text(message)
        }
      }
      .onAppear {
        startAutoScroll()
      }
      .onDisappear {
        stopAutoScroll()
      }
      .task {
        await loadProducts()
      }
    }
  }
  
  private func startAutoScroll() {
    stopAutoScroll() // Stop any existing timer
    autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
      let nextIndex = currentReviewIndex + 1
      let totalCount = reviews.count + 2 // reviews + 2 duplicates
      
      // If we're at the duplicate last item (index = totalCount - 1), jump to real first item (index 1) without animation
      if nextIndex == totalCount {
        // Jump to real first item without animation
        currentReviewIndex = 1
        // Small delay then continue to second item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          withAnimation(.easeInOut(duration: 1.2)) {
            currentReviewIndex = 2
          }
        }
      } else {
        withAnimation(.easeInOut(duration: 1.2)) {
          currentReviewIndex = nextIndex
        }
      }
    }
  }
  
  private func stopAutoScroll() {
    autoScrollTimer?.invalidate()
    autoScrollTimer = nil
  }
  
  @Environment(\.dismiss) private var dismiss
  @State private var selectedOption: SubscriptionOption = .lifetime
  @State private var currentReviewIndex: Int = 1 // Start at 1 (first real item)
  @State private var autoScrollTimer: Timer?
  @State private var isRestoring = false
  @State private var restoreMessage: String?
  @State private var showingRestoreAlert = false
  @State private var isPurchasing = false
  @State private var purchaseMessage: String?
  @State private var showingPurchaseAlert = false
  @State private var showingTermsConditions = false
  @State private var selectedLegalTab: Int = 0 // 0 = Terms, 1 = Privacy Policy
  @ObservedObject private var subscriptionManager = SubscriptionManager.shared
  
  // Dynamic pricing state
  @State private var products: [Product] = []
  @State private var isLoadingProducts = true
  @State private var productLoadError: String?
  
  /// Get the current subscription option based on active subscription
  private var currentSubscriptionOption: SubscriptionOption? {
    guard let productID = subscriptionManager.currentSubscriptionProductID else {
      return nil
    }
    
    switch productID {
    case SubscriptionManager.ProductID.lifetime:
      return .lifetime
    case SubscriptionManager.ProductID.annual:
      return .annual
    case SubscriptionManager.ProductID.monthly:
      return .monthly
    default:
      return nil
    }
  }
  
  private let reviews: [Review] = [
    Review(id: "1", text: "This app transformed my daily routine. Premium features are worth it!"),
    Review(id: "2", text: "Best habit tracker I've used. The insights are incredible."),
    Review(id: "3", text: "Love vacation mode! Perfect for breaks without losing my streak."),
    Review(id: "4", text: "Unlimited habits is a game changer. Highly recommend premium!")
  ]
  
  // Create infinite loop by duplicating first and last items
  private var infiniteReviews: [Review] {
    [reviews.last!] + reviews + [reviews.first!]
  }
  
  private var headerText: some View {
    (Text("Unlock your full Habitto experience with ")
       .font(.appBodyLarge)
       .fontWeight(.semibold)
       .foregroundColor(.text02.opacity(0.85)) +
     Text("Premium")
       .font(.system(size: 20, weight: .bold))
       .foregroundColor(.primary) +
     Text("")
    )
    .multilineTextAlignment(.center)
    .frame(maxWidth: 280) // Constrain width to force two lines
  }
  
  private var reviewCarousel: some View {
    VStack(spacing: 0) {
      TabView(selection: $currentReviewIndex) {
        ForEach(Array(infiniteReviews.enumerated()), id: \.offset) { index, review in
          reviewCard(review: review)
            .tag(index)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .frame(height: 100)
      .onChange(of: currentReviewIndex) { oldValue, newValue in
        // Handle seamless looping
        if newValue == 0 {
          // Jumped to duplicate first item at the beginning, move to real last item
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            currentReviewIndex = reviews.count
          }
        } else if newValue == infiniteReviews.count - 1 {
          // Jumped to duplicate last item at the end, move to real first item
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            currentReviewIndex = 1
          }
        }
        // Restart timer when user manually swipes
        startAutoScroll()
      }
      
      // Page controls (only show real reviews, not duplicates)
      HStack(spacing: 6) {
        ForEach(0..<reviews.count, id: \.self) { index in
          Circle()
            .fill((index + 1) == currentReviewIndex ? Color.primary : Color.text04.opacity(0.3))
            .frame(width: 6, height: 6)
            .animation(.easeInOut(duration: 0.2), value: currentReviewIndex)
        }
      }
      .padding(.top, 8)
      .frame(maxWidth: .infinity)
    }
    .onAppear {
      // Set initial position to first real item
      currentReviewIndex = 1
    }
  }
  
  private func reviewCard(review: Review) -> some View {
    VStack(alignment: .center, spacing: 12) {
      // 5 stars
      HStack(spacing: 4) {
        ForEach(0..<5) { _ in
          Image(systemName: "star.fill")
            .font(.system(size: 16))
            .foregroundColor(.warning)
        }
      }
      
      // Review text
      Text(review.text)
        .font(.appBodyMedium)
        .foregroundColor(.text01)
        .lineLimit(3)
        .multilineTextAlignment(.center)
    }
    .padding(16)
    .frame(maxWidth: .infinity)
    .background {
      RoundedRectangle(cornerRadius: 20)
        .fill(
          LinearGradient(
            gradient: Gradient(colors: [
              Color(hex: "F6F9FF"),
              Color(hex: "E9EFFF")
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    }
  }
  
  private var benefitsList: some View {
    VStack(alignment: .leading, spacing: 16) {
      ForEach(subscriptionFeatures, id: \.title) { feature in
        HStack(spacing: 12) {
          // Premium check icon
          if feature.isPremiumAvailable {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 20, weight: .semibold))
              .foregroundStyle(
                LinearGradient(
                  gradient: Gradient(colors: [
                    Color(hex: "74ADFA"),
                    Color(hex: "183288")
                  ]),
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
          }
          
          // Benefit title
          Text(feature.title)
            .font(.appBodyMedium)
            .foregroundColor(.text01)
        }
      }
    }
  }
  
  private var subscriptionOptions: some View {
    VStack(spacing: 12) {
      if isLoadingProducts {
        // Loading state
        VStack(spacing: 16) {
          ProgressView()
            .scaleEffect(1.2)
          Text("Loading prices...")
            .font(.appBodyMedium)
            .foregroundColor(.text02)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
      } else if let error = productLoadError {
        // Error state with retry button
        VStack(spacing: 16) {
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 32))
            .foregroundColor(.text03)
          Text("Failed to load prices")
            .font(.appBodyMedium)
            .foregroundColor(.text02)
          Text(error)
            .font(.appBodySmall)
            .foregroundColor(.text03)
            .multilineTextAlignment(.center)
          Button(action: {
            Task {
              await loadProducts()
            }
          }) {
            Text("Retry")
              .font(.appBodyMedium)
              .foregroundColor(.primary)
              .padding(.horizontal, 24)
              .padding(.vertical, 12)
              .background(Color.primary.opacity(0.1))
              .cornerRadius(12)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
      } else {
        // Content state with dynamic prices
        // Lifetime Access
        subscriptionOptionCard(
          option: .lifetime,
          emoji: "",
          title: "Lifetime Access",
          length: "Lifetime",
          price: priceString(for: .lifetime),
          badge: "Popular",
          showBadge: true,
          showCrossedPrice: false
        )
        
        // Annual
        subscriptionOptionCard(
          option: .annual,
          emoji: "",
          title: "Annual",
          length: "1 year",
          price: priceString(for: .annual),
          originalPrice: nil,
          badge: savingsPercentage() != nil ? "\(savingsPercentage()!)% off" : nil,
          showBadge: false, // ✅ Hidden: 50% off badge
          showCrossedPrice: false
        )
        
        // Monthly
        subscriptionOptionCard(
          option: .monthly,
          emoji: "",
          title: "Monthly",
          length: "1 month",
          price: priceString(for: .monthly),
          badge: nil,
          showBadge: false,
          showCrossedPrice: false
        )
      }
    }
    .onAppear {
      // Set initial selected option to current subscription if available, otherwise default to lifetime
      if let currentOption = currentSubscriptionOption {
        selectedOption = currentOption
      }
    }
  }
  
  private func subscriptionOptionCard(
    option: SubscriptionOption,
    emoji: String,
    title: String,
    length: String,
    price: String,
    originalPrice: String? = nil,
    badge: String?,
    showBadge: Bool,
    showCrossedPrice: Bool
  ) -> some View {
    let isCurrentPlan = currentSubscriptionOption == option
    let isSelected = selectedOption == option
    
    return Button(action: {
      // Don't allow selection of current plan
      if !isCurrentPlan {
        withAnimation(.easeInOut(duration: 0.2)) {
          selectedOption = option
        }
      }
    }) {
      HStack(spacing: 16) {
        if !emoji.isEmpty {
          Text(emoji)
            .font(.system(size: 24))
            .opacity(isCurrentPlan ? 0.5 : 1.0)
        }
        
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            if showBadge, let badge = badge {
              Text(badge)
                .font(SwiftUI.Font.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ColorTokens.secondary)
                .cornerRadius(8)
            }
            
            if isCurrentPlan {
              Text("Current Plan")
                .font(SwiftUI.Font.system(size: 10, weight: .semibold))
                .foregroundColor(.text02)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.text04.opacity(0.2))
                .cornerRadius(8)
            }
          }
          
          Text(title)
            .font(.appTitleMediumEmphasised)
            .foregroundColor(isCurrentPlan ? .text03 : .text02)
        }
        
        Spacer()
        
        // Duration and price on the right
        VStack(alignment: .trailing, spacing: 4) {
          Text(length)
            .font(.appBodySmall)
            .foregroundColor(isCurrentPlan ? .text04 : .text03)
          
          HStack(spacing: 8) {
            if showCrossedPrice, let originalPrice = originalPrice {
              Text(originalPrice)
                .font(.appBodySmall)
                .foregroundColor(.text04)
                .strikethrough()
            }
            
            Text(price)
              .font(.appBodySmallEmphasised)
              .foregroundColor(isCurrentPlan ? .text04 : .text05)
          }
        }
        
        // Radio button circle
        ZStack {
          Circle()
            .fill(isSelected ? (isCurrentPlan ? Color.text04.opacity(0.3) : Color.primary) : Color.clear)
            .frame(width: 24, height: 24)
            .animation(.easeInOut(duration: 0.2), value: selectedOption)
          
          Circle()
            .stroke(isSelected ? (isCurrentPlan ? Color.text04.opacity(0.5) : Color.primary) : Color.outline3, lineWidth: 2)
            .frame(width: 24, height: 24)
            .animation(.easeInOut(duration: 0.2), value: selectedOption)
            .opacity(isCurrentPlan ? 0.5 : 1.0)
          
          if isSelected {
            Circle()
              .fill(isCurrentPlan ? Color.text04.opacity(0.6) : .onPrimary)
              .frame(width: 8, height: 8)
              .animation(.easeInOut(duration: 0.2), value: selectedOption)
          }
        }
      }
      .padding(16)
      .background(isSelected ? (isCurrentPlan ? Color.text04.opacity(0.05) : Color.primary.opacity(0.05)) : Color.surface)
      .cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(isSelected ? (isCurrentPlan ? Color.text04.opacity(0.3) : Color.primary) : Color.outline3, lineWidth: 2)
      )
      .opacity(isCurrentPlan ? 0.7 : 1.0)
    }
    .buttonStyle(PlainButtonStyle())
    .disabled(isCurrentPlan)
  }
  
  // MARK: - Comparison Table
  
  private var comparisonTable: some View {
    let tableHeight = CGFloat(56 + (56 * subscriptionFeatures.count))
    
    return ZStack {
        // Free column background
        HStack(spacing: 0) {
          Spacer()
            .frame(maxWidth: .infinity)
          
          VStack(spacing: 0) {
            // Header row background
            Color.primaryContainer
              .opacity(0.4)
              .frame(height: 56)
            
            // Feature rows background
            ForEach(subscriptionFeatures, id: \.title) { _ in
              Color.navy50
                .opacity(0.4)
                .frame(height: 56)
            }
          }
          .frame(width: 80)
          .cornerRadius(16)
          
          // Premium column background
          Color.secondaryContainer
            .frame(width: 100, height: CGFloat(56 + (56 * subscriptionFeatures.count)))
            .cornerRadius(16)
            .overlay(
              RoundedRectangle(cornerRadius: 16)
                .stroke(ColorTokens.secondary, lineWidth: 2)
            )
        }
        
        // Main table
      VStack(spacing: 0) {
        // Table header
        HStack(spacing: 0) {
          Text("Benefits")
            .font(.appTitleSmallEmphasised)
            .fontWeight(.black)
            .foregroundColor(.text02)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
          
          Text("Free")
            .font(.appTitleSmallEmphasised)
            .fontWeight(.black)
            .foregroundColor(.text02)
            .frame(width: 80, alignment: .center)
            .background(Color.clear)
          
          Text("Premium")
            .font(.appTitleSmallEmphasised)
            .fontWeight(.black)
            .foregroundColor(.black)
            .frame(width: 100, alignment: .center)
            .background(Color.clear)
        }
        .padding(.vertical, 16)
        .frame(height: 56)
        .overlay(
          Rectangle()
            .frame(height: 1)
            .foregroundColor(.outline3),
          alignment: .bottom
        )
        
        // Table rows
        ForEach(Array(subscriptionFeatures.enumerated()), id: \.element.title) { index, feature in
          comparisonRow(feature: feature, isLast: index == subscriptionFeatures.count - 1)
        }
      }
      .cornerRadius(16)
    }
    .frame(height: tableHeight)
  }
  
  private func comparisonRow(feature: SubscriptionFeature, isLast: Bool) -> some View {
    HStack(spacing: 0) {
      // Benefit name
      Text(feature.title)
        .font(.appBodyMedium)
        .foregroundColor(.text01)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
      
      // Free column - transparent background so container shows through
      Group {
        if let freeText = feature.freeText {
          Text(freeText)
            .font(.appBodyMedium)
            .foregroundColor(.text01)
        } else {
          featureIcon(isAvailable: feature.isFreeAvailable, isPremium: false)
        }
      }
      .frame(width: 80, alignment: .center)
      .background(Color.clear)
      
      // Premium column - transparent background so gradient shows through
      featureIcon(isAvailable: feature.isPremiumAvailable, isPremium: true)
        .frame(width: 100, alignment: .center)
        .background(Color.clear)
    }
    .padding(.vertical, 16)
    .frame(height: 56)
    .overlay(
      Group {
        if !isLast {
          Rectangle()
            .frame(height: 1)
            .foregroundColor(.outline3)
        }
      },
      alignment: .bottom
    )
  }
  
  @ViewBuilder
  private func featureIcon(isAvailable: Bool, isPremium: Bool) -> some View {
    if isAvailable {
      if isPremium {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 24, weight: .semibold))
          .foregroundColor(.secondaryDim)
      } else {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(Color(hex: "FF7838")) // Orange for free
      }
    } else {
      Image(systemName: "xmark.circle.fill")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.text04) // Grey cross
        .opacity(0.5)
    }
  }
  
  private var ctaButton: some View {
    HabittoButton.largeFillPrimary(
      text: isPurchasing ? "Processing..." : "Begin free trial",
      state: isPurchasing ? .loading : .default
    ) {
      Task {
        await purchaseSubscription()
      }
    }
  }
  
  private var restorePurchaseButton: some View {
    HabittoButton(
      size: .medium,
      style: .outline,
      content: .text(isRestoring ? "Restoring..." : "Restore Purchases"),
      state: isRestoring ? .loading : .default
    ) {
      Task {
        await restorePurchases()
      }
    }
  }
  
  // MARK: - Legal Links
  
  private var legalLinks: some View {
    VStack(spacing: 12) {
      // Terms of Use link (Apple's standard EULA)
      Button(action: {
        openAppleStandardEULA()
      }) {
        HStack {
          Text("Terms of Use")
            .font(.appBodySmall)
            .foregroundColor(.primary)
          
          Spacer()
          
          Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.text03)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.surface)
        .cornerRadius(12)
      }
      
      // Privacy Policy link
      Button(action: {
        openPrivacyPolicy()
      }) {
        HStack {
          Text("Privacy Policy")
            .font(.appBodySmall)
            .foregroundColor(.primary)
          
          Spacer()
          
          Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.text03)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.surface)
        .cornerRadius(12)
      }
    }
  }
  
  private var mainLegalLinks: some View {
    HStack(spacing: 20) {
      // Terms of Use link (Apple's standard EULA)
      Button(action: {
        openAppleStandardEULA()
      }) {
        Text("Terms of Use")
          .font(.appBodySmall)
          .foregroundColor(.primary)
          .underline()
      }
      
      Text("•")
        .font(.appBodySmall)
        .foregroundColor(.text04)
      
      // Privacy Policy link
      Button(action: {
        openPrivacyPolicy()
      }) {
        Text("Privacy Policy")
          .font(.appBodySmall)
          .foregroundColor(.primary)
          .underline()
      }
    }
    .frame(maxWidth: .infinity)
  }
  
  private var subscriptionTerms: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("- Payment will be charged to your Apple ID account at confirmation of purchase")
        .font(.appBodySmall)
        .foregroundColor(.text02)
      
      Text("- Subscription automatically renews unless canceled at least 24 hours before the end of the current period")
        .font(.appBodySmall)
        .foregroundColor(.text02)
      
      Text("- Your account will be charged for renewal within 24 hours prior to the end of the current period")
        .font(.appBodySmall)
        .foregroundColor(.text02)
      
      Text("- You can manage and cancel your subscriptions by going to your App Store account settings after purchase")
        .font(.appBodySmall)
        .foregroundColor(.text02)
    }
  }
  
  /// Open Privacy Policy in Safari
  private func openPrivacyPolicy() {
    let privacyURL = "https://habittoapp.netlify.app/privacy"
    
    guard let url = URL(string: privacyURL) else {
      print("❌ SubscriptionView: Failed to create Privacy Policy URL")
      return
    }
    
    UIApplication.shared.open(url) { success in
      if success {
        print("✅ SubscriptionView: Opened Privacy Policy")
      } else {
        print("❌ SubscriptionView: Failed to open Privacy Policy URL")
      }
    }
  }
  
  /// Open Apple's standard Terms of Use (EULA) in Safari
  private func openAppleStandardEULA() {
    // Apple's standard EULA URL
    let eulaURL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    
    guard let url = URL(string: eulaURL) else {
      print("❌ SubscriptionView: Failed to create EULA URL")
      return
    }
    
    UIApplication.shared.open(url) { success in
      if success {
        print("✅ SubscriptionView: Opened Apple's standard EULA")
      } else {
        print("❌ SubscriptionView: Failed to open EULA URL")
      }
    }
  }
  
  /// Purchase the selected subscription
  private func purchaseSubscription() async {
    isPurchasing = true
    purchaseMessage = nil
    
    // Map selected option to product ID
    let productID: String
    switch selectedOption {
    case .lifetime:
      productID = SubscriptionManager.ProductID.lifetime
    case .annual:
      productID = SubscriptionManager.ProductID.annual
    case .monthly:
      productID = SubscriptionManager.ProductID.monthly
    }
    
    let result = await subscriptionManager.purchase(productID)
    
    await MainActor.run {
      isPurchasing = false
      purchaseMessage = result.message
      
      // If purchase was successful and user is now premium, dismiss the view
      if result.success && subscriptionManager.isPremium {
        showingPurchaseAlert = true
        // Dismiss the entire view after showing success message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
          dismiss()
        }
      } else {
        // For errors, show alert immediately
        showingPurchaseAlert = true
      }
    }
  }
  
  // MARK: - Dynamic Pricing Helpers
  
  /// Load products from StoreKit
  private func loadProducts() async {
    isLoadingProducts = true
    productLoadError = nil
    
    let loadedProducts = await subscriptionManager.getAvailableProducts()
    
    await MainActor.run {
      self.products = loadedProducts
      self.isLoadingProducts = false
      
      if loadedProducts.isEmpty {
        self.productLoadError = "No products available. Please check your internet connection."
      }
    }
  }
  
  /// Get the Product for a given subscription option
  private func product(for option: SubscriptionOption) -> Product? {
    let productID: String
    switch option {
    case .lifetime:
      productID = SubscriptionManager.ProductID.lifetime
    case .annual:
      productID = SubscriptionManager.ProductID.annual
    case .monthly:
      productID = SubscriptionManager.ProductID.monthly
    }
    
    return products.first { $0.id == productID }
  }
  
  /// Get the price string for a subscription option
  private func priceString(for option: SubscriptionOption) -> String {
    guard let product = product(for: option) else {
      // Fallback to hardcoded prices if product not loaded
      switch option {
      case .lifetime:
        return "€24.99"
      case .annual:
        return "€12.99/year"
      case .monthly:
        return "€1.99/month"
      }
    }
    
    switch option {
    case .lifetime:
      return product.displayPrice
    case .annual:
      return "\(product.displayPrice)/year"
    case .monthly:
      return "\(product.displayPrice)/month"
    }
  }
  
  /// Calculate savings percentage (annual vs 12× monthly)
  private func savingsPercentage() -> Int? {
    guard let annualProduct = product(for: .annual),
          let monthlyProduct = product(for: .monthly) else {
      return nil
    }
    
    // Get numeric prices
    let annualPrice = annualProduct.price
    let monthlyPrice = monthlyProduct.price
    let monthlyYearlyPrice = monthlyPrice * 12
    
    guard monthlyYearlyPrice > 0 else { return nil }
    
    let savings = ((monthlyYearlyPrice - annualPrice) / monthlyYearlyPrice) * 100
    return Int(NSDecimalNumber(decimal: savings).doubleValue.rounded())
  }
  
  /// Calculate original annual price (12× monthly price)
  private func originalAnnualPrice() -> String? {
    guard let monthlyProduct = product(for: .monthly) else {
      return nil
    }
    
    // Calculate 12× monthly price
    let monthlyPrice = monthlyProduct.price
    let yearlyPrice = monthlyPrice * 12
    
    // Format using currency formatter with current locale
    // StoreKit's displayPrice is already in the user's App Store currency,
    // so we use the current locale which should match
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale.current
    
    guard let formattedPrice = formatter.string(from: NSDecimalNumber(decimal: yearlyPrice)) else {
      return nil
    }
    
    return formattedPrice
  }
  
  /// Restore previous purchases
  private func restorePurchases() async {
    isRestoring = true
    restoreMessage = nil
    
    let result = await subscriptionManager.restorePurchases()
    
    await MainActor.run {
      isRestoring = false
      restoreMessage = result.message
      
      // If restore was successful and user is now premium, dismiss the view
      if result.success && subscriptionManager.isPremium {
        // Show alert first, then dismiss after showing success message
        showingRestoreAlert = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
          dismiss()
        }
      } else {
        // For errors, show alert immediately
        showingRestoreAlert = true
      }
    }
  }
  
  private let subscriptionFeatures: [SubscriptionFeature] = [
    SubscriptionFeature(
      title: "Unlimited Habits",
      freeText: "5 max",
      isFreeAvailable: true,
      isPremiumAvailable: true
    ),
    SubscriptionFeature(
      title: "Progress Insights",
      isFreeAvailable: false,
      isPremiumAvailable: true
    ),
    SubscriptionFeature(
      title: "Vacation Mode",
      isFreeAvailable: false,
      isPremiumAvailable: true
    ),
    SubscriptionFeature(
      title: "All Future Features",
      isFreeAvailable: false,
      isPremiumAvailable: true
    )
  ]
}

// MARK: - SubscriptionOption

enum SubscriptionOption {
  case lifetime
  case annual
  case monthly
}

// MARK: - Review

struct Review {
  let id: String
  let text: String
}

// MARK: - SubscriptionFeature

struct SubscriptionFeature {
  let title: String
  let freeText: String?
  let isFreeAvailable: Bool
  let isPremiumAvailable: Bool
  
  init(title: String, freeText: String? = nil, isFreeAvailable: Bool, isPremiumAvailable: Bool) {
    self.title = title
    self.freeText = freeText
    self.isFreeAvailable = isFreeAvailable
    self.isPremiumAvailable = isPremiumAvailable
  }
}


import SwiftUI
import Combine
import UIKit

// MARK: - SubscriptionView

struct SubscriptionView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      ZStack(alignment: .bottom) {
        // Background
        Image("secondaryBlueGradient(top,bottom)@4x")
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .ignoresSafeArea(.all)
        
        ScrollView {
          VStack(spacing: 0) {
            // Header text
            headerText
              .padding(.top, 20)
              .padding(.bottom, 32)
            
            // Comparison table
            comparisonTable
              .padding(.bottom, 32)
            
            // Review carousel
            reviewCarousel
              .padding(.bottom, 32)
            
            // Legal links (Privacy Policy and Terms of Use)
            mainLegalLinks
              .padding(.bottom, 16)
            
            // Subscription terms
            subscriptionTerms
              .padding(.bottom, 40)
            
            // Benefits list (commented out for future use)
            // benefitsList
            //   .padding(.bottom, 32)
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
      .sheet(isPresented: $showingSubscriptionOptions) {
        subscriptionOptionsSheet
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
  @State private var showingSubscriptionOptions = false
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
       .foregroundColor(.text02.opacity(0.85)) +
     Text("Premium")
       .font(.system(size: 28, weight: .black))
       .foregroundColor(.primary) +
     Text("")
    )
    .font(.appHeadlineMedium)
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
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
            .foregroundColor(Color("yellow300"))
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
  
  private var subscriptionOptionsSheet: some View {
    NavigationView {
      VStack(spacing: 0) {
        ScrollView {
          VStack(spacing: 20) {
            // Profile image
            Image("Default-Profile@4x")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 80, height: 80)
              .clipShape(Circle())
            
            subscriptionOptions
            
            // Privacy Policy and Terms of Use links
            mainLegalLinks
              .padding(.top, 8)
            
            // Subscription terms
            subscriptionTerms
              .padding(.top, 16)
          }
          .padding(.horizontal, 20)
          .padding(.top, 20)
          .padding(.bottom, 20)
        }
        
        // Bottom buttons
        VStack(spacing: 12) {
          HabittoButton.largeFillPrimary(
            text: isPurchasing ? "Processing..." : "Continue",
            state: isPurchasing ? .loading : .default
          ) {
            Task {
              await purchaseSubscription()
            }
          }
          
          HabittoButton(
            size: .medium,
            style: .tertiary,
            content: .text("Maybe Later"),
            action: {
              showingSubscriptionOptions = false
            }
          )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .padding(.top, 12)
        .background(Color.surface)
      }
      .navigationTitle("Choose Your Plan")
      .navigationBarTitleDisplayMode(.inline)
    }
    .presentationDetents([.height(650), .large])
    .presentationDragIndicator(.visible)
  }
  
  private var subscriptionOptions: some View {
    VStack(spacing: 12) {
      // Lifetime Access
      subscriptionOptionCard(
        option: .lifetime,
        emoji: "",
        title: "Lifetime Access",
        length: "Lifetime",
        price: "€24.99",
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
        price: "€12.99/year",
        originalPrice: "€23.88",
        badge: "50% off",
        showBadge: true,
        showCrossedPrice: true
      )
      
      // Monthly
      subscriptionOptionCard(
        option: .monthly,
        emoji: "",
        title: "Monthly",
        length: "1 month",
        price: "€1.99/month",
        badge: nil,
        showBadge: false,
        showCrossedPrice: false
      )
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
    Button(action: {
      withAnimation(.easeInOut(duration: 0.2)) {
        selectedOption = option
      }
    }) {
      HStack(spacing: 16) {
        if !emoji.isEmpty {
          Text(emoji)
            .font(.system(size: 24))
        }
        
        VStack(alignment: .leading, spacing: 4) {
          if showBadge, let badge = badge {
            Text(badge)
              .font(.system(size: 10, weight: .semibold))
              .foregroundColor(Color("navy900"))
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color("pastelBlue300"))
              .cornerRadius(8)
          }
          
          Text(title)
            .font(.appTitleMediumEmphasised)
            .foregroundColor(.text02)
          
          Text(length)
            .font(.appBodySmall)
            .foregroundColor(.text03)
          
          HStack(spacing: 8) {
            if showCrossedPrice, let originalPrice = originalPrice {
              Text(originalPrice)
                .font(.appBodySmall)
                .foregroundColor(.text04)
                .strikethrough()
            }
            
            Text(price)
              .font(.appBodySmallEmphasised)
              .foregroundColor(.text05)
          }
        }
        
        Spacer()
        
        // Radio button circle
        ZStack {
          Circle()
            .fill(selectedOption == option ? Color.primary : Color.clear)
            .frame(width: 24, height: 24)
            .animation(.easeInOut(duration: 0.2), value: selectedOption)
          
          Circle()
            .stroke(selectedOption == option ? Color.primary : Color.outline3, lineWidth: 2)
            .frame(width: 24, height: 24)
            .animation(.easeInOut(duration: 0.2), value: selectedOption)
          
          if selectedOption == option {
            Circle()
              .fill(Color.white)
              .frame(width: 8, height: 8)
              .animation(.easeInOut(duration: 0.2), value: selectedOption)
          }
        }
      }
      .padding(16)
      .background(selectedOption == option ? Color.primary.opacity(0.05) : Color.surface)
      .cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(selectedOption == option ? Color.primary : Color.outline3, lineWidth: 2)
      )
    }
    .buttonStyle(PlainButtonStyle())
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
            Color.navy50
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
          Color("pastelBlue100")
            .frame(width: 100, height: CGFloat(56 + (56 * subscriptionFeatures.count)))
            .cornerRadius(16)
            .overlay(
              RoundedRectangle(cornerRadius: 16)
                .stroke(Color("pastelBlue300"), lineWidth: 2)
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
          .foregroundColor(Color("pastelBlue500"))
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
    HabittoButton.largeFillPrimary(text: "See all plans") {
      showingSubscriptionOptions = true
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
    .padding(16)
    .background(Color.surface)
    .cornerRadius(12)
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
      
      // If purchase was successful and user is now premium, dismiss the sheet first
      if result.success && subscriptionManager.isPremium {
        showingSubscriptionOptions = false
        // Wait for sheet dismissal animation to complete (iOS sheet animations are ~0.3-0.4s)
        // Add extra buffer to ensure all view transitions complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
          // Ensure we're still on main thread and view is still present
          Task { @MainActor in
            showingPurchaseAlert = true
            // Then dismiss the entire view after showing success message
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
              dismiss()
            }
          }
        }
      } else {
        // For errors, show alert immediately (sheet stays open)
        showingPurchaseAlert = true
      }
    }
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


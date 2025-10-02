import Foundation
import OSLog

// MARK: - Auth Routing Manager
/// Manages repository switching and user isolation on authentication changes
@MainActor
final class AuthRoutingManager: ObservableObject {
    static let shared = AuthRoutingManager()
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "AuthRoutingManager")
    private let featureFlags: FeatureFlagProvider
    
    // Repository provider for current user
    private var repositoryProvider: RepositoryProviderProtocol?
    
    // Current user context
    private var currentUserId: String?
    
    private init() {
        self.featureFlags = FeatureFlagManager.shared.provider
        setupAuthStateListener()
    }
    
    init(featureFlags: FeatureFlagProvider) {
        self.featureFlags = featureFlags
        setupAuthStateListener()
    }
    
    // MARK: - Public Interface
    
    /// Gets the current repository provider
    var currentRepositoryProvider: RepositoryProviderProtocol {
        get {
            if let existing = repositoryProvider {
                return existing
            }
            
            let provider = createRepositoryProvider()
            repositoryProvider = provider
            return provider
        }
    }
    
    /// Gets the current user ID
    var currentUser: String? {
        return currentUserId
    }
    
    // MARK: - Authentication State Management
    
    private func setupAuthStateListener() {
        // Listen to authentication state changes
        AuthenticationManager.shared.$authState
            .sink { [weak self] authState in
                Task { @MainActor in
                    await self?.handleAuthStateChange(authState)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleAuthStateChange(_ authState: AuthenticationState) async {
        logger.info("AuthRoutingManager: Handling auth state change: \(String(describing: authState))")
        
        switch authState {
        case .unauthenticated:
            await switchToGuestUser()
            
        case .authenticated(let user):
            await switchToUser(userId: user.uid)
            
        case .authenticating:
            logger.info("AuthRoutingManager: User authenticating, no action needed")
            
        case .error(let message):
            logger.error("AuthRoutingManager: Authentication error: \(message)")
            await switchToGuestUser()
        }
    }
    
    private func switchToGuestUser() async {
        logger.info("AuthRoutingManager: Switching to guest user")
        
        let guestUserId = "guest_user"
        
        // Log auth switch
        ObservabilityLogger.shared.logAuthSwitch(fromUserId: currentUserId, toUserId: guestUserId, reason: "sign_out")
        
        do {
            // Clear existing repository provider
            repositoryProvider = nil
            
            // Create new repository provider for guest
            let provider = createRepositoryProvider()
            try await provider.reinitializeForUser(userId: guestUserId)
            
            repositoryProvider = provider
            currentUserId = guestUserId
            
            logger.info("AuthRoutingManager: Successfully switched to guest user")
            
        } catch {
            logger.error("AuthRoutingManager: Failed to switch to guest user: \(error.localizedDescription)")
        }
    }
    
    private func switchToUser(userId: String) async {
        logger.info("AuthRoutingManager: Switching to user \(userId)")
        
        // Log auth switch
        ObservabilityLogger.shared.logAuthSwitch(fromUserId: currentUserId, toUserId: userId, reason: "sign_in")
        
        do {
            // Clear existing repository provider
            repositoryProvider = nil
            
            // Create new repository provider for user
            let provider = createRepositoryProvider()
            try await provider.reinitializeForUser(userId: userId)
            
            repositoryProvider = provider
            currentUserId = userId
            
            logger.info("AuthRoutingManager: Successfully switched to user \(userId)")
            
        } catch {
            logger.error("AuthRoutingManager: Failed to switch to user \(userId): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Repository Provider Creation
    
    private func createRepositoryProvider() -> RepositoryProviderProtocol {
        return RepositoryProvider()
    }
    
    // MARK: - Manual User Switching (for testing)
    
    /// Manually switch to a specific user (for testing purposes)
    func manuallySwitchToUser(userId: String) async throws {
        await switchToUser(userId: userId)
    }
    
    /// Manually switch to guest user (for testing purposes)
    func switchToGuest() async throws {
        await switchToGuestUser()
    }
    
    // MARK: - Cache Management
    
    /// Clear all caches and reset to initial state
    func clearAllCaches() {
        logger.info("AuthRoutingManager: Clearing all caches")
        
        repositoryProvider = nil
        currentUserId = nil
        
        // Clear singleton caches
        XPManager.shared.handleUserSignOut()
        
        logger.info("AuthRoutingManager: All caches cleared")
    }
    
    // MARK: - Feature Flag Updates
    
    /// Update feature flags and reinitialize if needed
    func updateFeatureFlags() async {
        logger.info("AuthRoutingManager: Updating feature flags")
        
        // Clear existing repository provider to force recreation
        repositoryProvider = nil
        
        // If we have a current user, reinitialize
        if let userId = currentUserId {
            await switchToUser(userId: userId)
        } else {
            await switchToGuestUser()
        }
    }
    
    // MARK: - Testing Support
    
    /// Set a test repository provider (for testing purposes)
    func setTestRepositoryProvider(_ provider: RepositoryProviderProtocol) {
        repositoryProvider = provider
    }
    
    /// Get current repository provider for testing
    func getCurrentRepositoryProvider() -> RepositoryProviderProtocol? {
        return repositoryProvider
    }
}

// MARK: - Auth Routing Manager Extensions
extension AuthRoutingManager {
    /// Check if current user is guest
    var isGuestUser: Bool {
        return currentUserId == "guest_user"
    }
    
    /// Check if current user is authenticated
    var isAuthenticated: Bool {
        return currentUserId != nil && currentUserId != "guest_user"
    }
    
    /// Get current user ID or guest fallback
    var currentUserIdOrGuest: String {
        return currentUserId ?? "guest_user"
    }
}

// MARK: - Combine Support
import Combine

private var cancellables = Set<AnyCancellable>()

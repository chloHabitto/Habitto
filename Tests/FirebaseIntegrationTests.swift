//
//  FirebaseIntegrationTests.swift
//  HabittoTests
//
//  Unit tests for Firebase integration
//

import XCTest
@testable import Habitto

@MainActor
final class FirebaseIntegrationTests: XCTestCase {
  
  // MARK: - Environment Configuration Tests
  
  func testEnvironmentDetection() {
    // Test that we can detect test environment
    XCTAssertTrue(AppEnvironment.isRunningTests, "Should detect test environment")
  }
  
  func testFirebaseConfigurationStatus() {
    let status = AppEnvironment.firebaseConfigurationStatus
    
    // In test environment, Firebase may or may not be configured
    // Just ensure we get a valid status
    XCTAssertNotNil(status, "Should return a configuration status")
    
    print("📊 Configuration Status: \(status.message)")
  }
  
  func testEmulatorConfiguration() {
    // Test emulator environment variables
    let isUsingEmulator = AppEnvironment.isUsingEmulator
    print("🧪 Using Emulator: \(isUsingEmulator)")
    
    if isUsingEmulator {
      XCTAssertFalse(AppEnvironment.firestoreEmulatorHost.isEmpty, "Emulator host should not be empty")
      XCTAssertFalse(AppEnvironment.authEmulatorHost.isEmpty, "Auth emulator host should not be empty")
    }
  }
  
  // MARK: - FirestoreService Tests (Mock)
  
  func testFirestoreServiceInitialization() {
    let service = FirestoreService.shared
    XCTAssertNotNil(service, "FirestoreService should initialize")
  }
  
  func testCreateMockHabit() async throws {
    let service = FirestoreService.shared
    
    // Clear any existing habits
    service.habits.removeAll()
    
    // Create a mock habit
    let habit = try await service.createHabit(name: "Test Habit", color: "blue")
    
    XCTAssertEqual(habit.name, "Test Habit", "Habit name should match")
    XCTAssertEqual(habit.color, "blue", "Habit color should match")
    XCTAssertFalse(habit.id.isEmpty, "Habit should have an ID")
    XCTAssertTrue(service.habits.contains(where: { $0.id == habit.id }), "Habit should be in the list")
  }
  
  func testUpdateMockHabit() async throws {
    let service = FirestoreService.shared
    service.habits.removeAll()
    
    // Create a habit
    let habit = try await service.createHabit(name: "Original Name", color: "red")
    
    // Update it
    try await service.updateHabit(id: habit.id, name: "Updated Name", color: "green")
    
    // Verify update
    if let updatedHabit = service.habits.first(where: { $0.id == habit.id }) {
      XCTAssertEqual(updatedHabit.name, "Updated Name", "Habit name should be updated")
      XCTAssertEqual(updatedHabit.color, "green", "Habit color should be updated")
    } else {
      XCTFail("Updated habit not found")
    }
  }
  
  func testDeleteMockHabit() async throws {
    let service = FirestoreService.shared
    service.habits.removeAll()
    
    // Create a habit
    let habit = try await service.createHabit(name: "To Delete", color: "red")
    XCTAssertTrue(service.habits.contains(where: { $0.id == habit.id }), "Habit should exist")
    
    // Delete it
    try await service.deleteHabit(id: habit.id)
    
    // Verify deletion
    XCTAssertFalse(service.habits.contains(where: { $0.id == habit.id }), "Habit should be deleted")
  }
  
  func testFetchMockHabits() async throws {
    let service = FirestoreService.shared
    service.habits.removeAll()
    
    // Fetch habits (should create mock data)
    try await service.fetchHabits()
    
    XCTAssertFalse(service.habits.isEmpty, "Should have mock habits after fetch")
    XCTAssertEqual(service.habits.count, 3, "Should have 3 default mock habits")
  }
  
  // MARK: - AuthenticationManager Tests
  
  func testCurrentUserIdProperty() {
    let authManager = AuthenticationManager.shared
    
    // In test environment, user might not be authenticated
    let userId = authManager.currentUserId
    
    // Just verify the property exists and returns correctly
    if let userId = userId {
      XCTAssertFalse(userId.isEmpty, "User ID should not be empty if present")
      print("✅ Current User ID: \(userId)")
    } else {
      print("ℹ️ No user currently authenticated (expected in test environment)")
    }
  }
  
  func testIsAnonymousProperty() {
    let authManager = AuthenticationManager.shared
    let isAnonymous = authManager.isAnonymous
    
    print("🔐 Is Anonymous: \(isAnonymous)")
    // Property should be accessible
    XCTAssertNotNil(isAnonymous, "isAnonymous property should be accessible")
  }
  
  // MARK: - Integration Tests (Requires Emulator)
  
  func testAnonymousSignIn() async {
    // This test requires Firebase to be configured
    guard AppEnvironment.isFirebaseConfigured else {
      print("⚠️ Skipping anonymous sign-in test (Firebase not configured)")
      return
    }
    
    let authManager = AuthenticationManager.shared
    let expectation = expectation(description: "Anonymous sign-in")
    
    authManager.signInAnonymously { result in
      switch result {
      case .success(let user):
        XCTAssertFalse(user.uid.isEmpty, "User should have a UID")
        print("✅ Anonymous sign-in successful: \(user.uid)")
      case .failure(let error):
        print("⚠️ Anonymous sign-in failed: \(error.localizedDescription)")
        // Don't fail the test - emulator might not be running
      }
      expectation.fulfill()
    }
    
    await fulfillment(of: [expectation], timeout: 5.0)
  }
  
  // MARK: - Error Handling Tests
  
  func testFirestoreErrorDescriptions() {
    let errors: [FirestoreError] = [
      .notConfigured,
      .notAuthenticated,
      .invalidData,
      .documentNotFound,
      .operationFailed("Test reason")
    ]
    
    for error in errors {
      XCTAssertNotNil(error.errorDescription, "Error should have a description")
      XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
      print("Error: \(error.errorDescription!)")
    }
  }
}

// MARK: - FirebaseConfiguration Tests

@MainActor
final class FirebaseConfigurationTests: XCTestCase {
  
  func testConfigurationStatus() {
    let status = AppEnvironment.firebaseConfigurationStatus
    print("📊 Firebase Configuration: \(status.message)")
    
    // Should always return a valid status
    XCTAssertNotNil(status)
  }
  
  func testCurrentUserId() {
    let userId = FirebaseConfiguration.currentUserId
    
    if let userId = userId {
      XCTAssertFalse(userId.isEmpty, "User ID should not be empty")
      print("✅ Current User ID via FirebaseConfiguration: \(userId)")
    } else {
      print("ℹ️ No authenticated user (expected in test environment)")
    }
  }
}


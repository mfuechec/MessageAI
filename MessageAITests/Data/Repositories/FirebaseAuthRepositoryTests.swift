import XCTest
import Combine
import FirebaseAuth
@testable import MessageAI

/// Integration tests for FirebaseAuthRepository using Firebase Emulator
///
/// These tests verify authentication flow with real Firebase SDK operations
/// against the Firebase Emulator. Requires emulator to be running.
@MainActor
final class FirebaseAuthRepositoryTests: XCTestCase {
    
    var sut: FirebaseAuthRepository!
    var firebaseService: FirebaseService!
    var userRepository: FirebaseUserRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Skip all tests if emulator not running
        // To run these tests: ./scripts/start-emulator.sh
        try XCTSkipIf(true, "Requires Firebase Emulator - start with ./scripts/start-emulator.sh")
        
        cancellables = Set<AnyCancellable>()
        
        // Configure Firebase with emulator
        firebaseService = FirebaseService()
        firebaseService.useEmulator()
        firebaseService.configure()
        
        // Initialize repositories
        userRepository = FirebaseUserRepository(firebaseService: firebaseService)
        sut = FirebaseAuthRepository(firebaseService: firebaseService, userRepository: userRepository)
        
        // Clean emulator state
        try await cleanEmulatorAuth()
    }
    
    override func tearDown() async throws {
        try await cleanEmulatorAuth()
        cancellables = nil
        sut = nil
        userRepository = nil
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func cleanEmulatorAuth() async throws {
        // Sign out current user if any
        if Auth.auth().currentUser != nil {
            try await sut.signOut()
        }
    }
    
    // MARK: - Sign Up Tests
    
    func testSignUp_Success() async throws {
        // Given
        let email = "test@example.com"
        let password = "password123"
        
        // When
        let user = try await sut.signUp(email: email, password: password)
        
        // Then
        XCTAssertEqual(user.email, email)
        XCTAssertFalse(user.id.isEmpty)
        XCTAssertEqual(user.displayName, "test") // Extracted from email
        XCTAssertTrue(user.isOnline)
    }
    
    func testSignUp_CreatesUserDocument() async throws {
        // Given
        let email = "newuser@example.com"
        let password = "password123"
        
        // When
        let user = try await sut.signUp(email: email, password: password)
        
        // Then: Verify user exists in Firestore
        let fetchedUser = try await sut.getCurrentUser()
        XCTAssertNotNil(fetchedUser)
        XCTAssertEqual(fetchedUser?.id, user.id)
    }
    
    func testSignUp_ExtractsDisplayNameFromEmail() async throws {
        // Given
        let email = "john.doe@example.com"
        let password = "password123"
        
        // When
        let user = try await sut.signUp(email: email, password: password)
        
        // Then
        XCTAssertEqual(user.displayName, "john.doe")
    }
    
    // MARK: - Sign In Tests
    
    func testSignIn_Success() async throws {
        // Given: Create user first
        let email = "signin@example.com"
        let password = "password123"
        _ = try await sut.signUp(email: email, password: password)
        try await sut.signOut()
        
        // When: Sign in
        let user = try await sut.signIn(email: email, password: password)
        
        // Then
        XCTAssertEqual(user.email, email)
        XCTAssertTrue(user.isOnline)
    }
    
    func testSignIn_InvalidCredentials() async throws {
        // Given
        let email = "nonexistent@example.com"
        let password = "wrongpassword"
        
        // When/Then
        do {
            _ = try await sut.signIn(email: email, password: password)
            XCTFail("Should throw error for invalid credentials")
        } catch {
            // Expected error
            XCTAssertTrue(error is RepositoryError || error is NSError)
        }
    }
    
    func testSignIn_UpdatesOnlineStatus() async throws {
        // Given: Create and sign out user
        let email = "online@example.com"
        let password = "password123"
        _ = try await sut.signUp(email: email, password: password)
        try await sut.signOut()
        
        // When: Sign in
        let user = try await sut.signIn(email: email, password: password)
        
        // Then
        XCTAssertTrue(user.isOnline)
    }
    
    // MARK: - Sign Out Tests
    
    func testSignOut_Success() async throws {
        // Given: Authenticated user
        let email = "signout@example.com"
        let password = "password123"
        _ = try await sut.signUp(email: email, password: password)
        
        // When
        try await sut.signOut()
        
        // Then
        let currentUser = try await sut.getCurrentUser()
        XCTAssertNil(currentUser)
    }
    
    func testSignOut_WhenNotAuthenticated() async throws {
        // Given: No authenticated user
        
        // When/Then: Should not throw
        try await sut.signOut()
    }
    
    // MARK: - Get Current User Tests
    
    func testGetCurrentUser_WhenAuthenticated() async throws {
        // Given
        let email = "current@example.com"
        let password = "password123"
        let signedUpUser = try await sut.signUp(email: email, password: password)
        
        // When
        let currentUser = try await sut.getCurrentUser()
        
        // Then
        XCTAssertNotNil(currentUser)
        XCTAssertEqual(currentUser?.id, signedUpUser.id)
        XCTAssertEqual(currentUser?.email, email)
    }
    
    func testGetCurrentUser_WhenNotAuthenticated() async throws {
        // Given: No authenticated user
        
        // When
        let currentUser = try await sut.getCurrentUser()
        
        // Then
        XCTAssertNil(currentUser)
    }
    
    // MARK: - Observe Auth State Tests
    
    func testObserveAuthState_EmitsUserOnSignIn() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Auth state emits user")
        var receivedUser: MessageAI.User?
        
        let cancellable = sut.observeAuthState()
            .sink { user in
                receivedUser = user
                expectation.fulfill()
            }
        
        // When
        let email = "observe@example.com"
        let password = "password123"
        _ = try await sut.signUp(email: email, password: password)
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertNotNil(receivedUser)
        XCTAssertEqual(receivedUser?.email, email)
        
        cancellable.cancel()
    }
    
    func testObserveAuthState_EmitsNilOnSignOut() async throws {
        // Given: Authenticated user
        let email = "observeout@example.com"
        let password = "password123"
        _ = try await sut.signUp(email: email, password: password)
        
        let expectation = XCTestExpectation(description: "Auth state emits nil")
        var receivedUser: MessageAI.User?
        var emissionCount = 0
        
        let cancellable = sut.observeAuthState()
            .sink { user in
                emissionCount += 1
                receivedUser = user
                if emissionCount == 2 {
                    expectation.fulfill()
                }
            }
        
        // Wait for initial emission
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // When
        try await sut.signOut()
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertNil(receivedUser)
        
        cancellable.cancel()
    }
}

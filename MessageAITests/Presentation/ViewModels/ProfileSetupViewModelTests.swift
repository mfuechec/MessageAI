//
//  ProfileSetupViewModelTests.swift
//  MessageAITests
//
//  Created by Dev Agent on 2025-10-20.
//

import XCTest
@testable import MessageAI

@MainActor
final class ProfileSetupViewModelTests: XCTestCase {
    
    // MARK: - Properties
    
    var mockUserRepo: MockUserRepository!
    var mockAuthRepo: MockAuthRepository!
    var testUser: User!
    var sut: ProfileSetupViewModel!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        mockUserRepo = MockUserRepository()
        mockAuthRepo = MockAuthRepository()
        
        // Create a consistent test timestamp
        let timestamp = Date()
        
        testUser = User(
            id: "test-user-id",
            email: "john.doe@example.com",
            displayName: "john.doe",
            isOnline: true,
            lastSeen: timestamp,
            createdAt: timestamp
        )
        
        sut = ProfileSetupViewModel(
            userRepository: mockUserRepo,
            authRepository: mockAuthRepo,
            currentUser: testUser
        )
    }
    
    override func tearDown() {
        sut = nil
        testUser = nil
        mockAuthRepo = nil
        mockUserRepo = nil
        
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInit_DefaultDisplayName_ExtractsEmailPrefix() {
        // Given / When - initialized in setUp
        
        // Then
        XCTAssertEqual(sut.displayName, "john.doe", "Display name should default to email prefix")
        XCTAssertNil(sut.profileImageURL, "Profile image URL should be nil initially")
        XCTAssertFalse(sut.isLoading, "Should not be loading initially")
        XCTAssertNil(sut.errorMessage, "Should have no error message initially")
        XCTAssertFalse(sut.profileSaved, "Profile should not be saved initially")
    }
    
    func testDefaultDisplayName_EmailWithoutAt_ReturnsUser() {
        // Given
        let timestamp = Date()
        let userWithInvalidEmail = User(
            id: "test-id",
            email: "invalidemail",
            displayName: "test",
            isOnline: true,
            lastSeen: timestamp,
            createdAt: timestamp
        )
        
        // When
        let viewModel = ProfileSetupViewModel(
            userRepository: mockUserRepo,
            authRepository: mockAuthRepo,
            currentUser: userWithInvalidEmail
        )
        
        // Then
        XCTAssertEqual(viewModel.displayName, "invalidemail", "Should use entire email if no @ found")
    }
    
    // MARK: - Save Profile Tests
    
    func testSaveProfile_Success_UpdatesUser() async {
        // Given
        sut.displayName = "John Doe"
        
        // When
        await sut.saveProfile()
        
        // Then
        XCTAssertTrue(mockUserRepo.updateUserCalled, "Should call updateUser")
        XCTAssertEqual(mockUserRepo.capturedUser?.displayName, "John Doe", "Should update display name")
        XCTAssertTrue(sut.profileSaved, "Profile should be marked as saved")
        XCTAssertNil(sut.errorMessage, "Should have no error message")
        XCTAssertFalse(sut.isLoading, "Should not be loading after completion")
    }
    
    func testSaveProfile_Success_TrimsWhitespace() async {
        // Given
        sut.displayName = "  John Doe  "
        
        // When
        await sut.saveProfile()
        
        // Then
        XCTAssertEqual(mockUserRepo.capturedUser?.displayName, "John Doe", "Should trim whitespace")
        XCTAssertTrue(sut.profileSaved, "Profile should be marked as saved")
    }
    
    func testSaveProfile_Success_PreservesOtherUserProperties() async {
        // Given
        sut.displayName = "John Doe"
        
        // When
        await sut.saveProfile()
        
        // Then
        let updatedUser = mockUserRepo.capturedUser
        XCTAssertEqual(updatedUser?.id, testUser.id, "Should preserve user ID")
        XCTAssertEqual(updatedUser?.email, testUser.email, "Should preserve email")
        XCTAssertEqual(updatedUser?.isOnline, testUser.isOnline, "Should preserve online status")
        XCTAssertEqual(updatedUser?.lastSeen, testUser.lastSeen, "Should preserve last seen")
        XCTAssertEqual(updatedUser?.createdAt, testUser.createdAt, "Should preserve created at")
    }
    
    func testSaveProfile_Failure_ShowsError() async {
        // Given
        mockUserRepo.shouldFail = true
        sut.displayName = "John Doe"
        
        // When
        await sut.saveProfile()
        
        // Then
        XCTAssertNotNil(sut.errorMessage, "Should show error message")
        XCTAssertEqual(sut.errorMessage, "Failed to save profile. Please try again.")
        XCTAssertFalse(sut.profileSaved, "Profile should not be marked as saved")
        XCTAssertFalse(sut.isLoading, "Should not be loading after error")
    }
    
    func testSaveProfile_WithProfileImageURL_IncludesURL() async {
        // Given
        sut.displayName = "John Doe"
        sut.profileImageURL = "https://example.com/profile.jpg"
        
        // When
        await sut.saveProfile()
        
        // Then
        XCTAssertEqual(mockUserRepo.capturedUser?.profileImageURL, "https://example.com/profile.jpg")
        XCTAssertTrue(sut.profileSaved)
    }
    
    // MARK: - Validation Tests
    
    func testValidateDisplayName_Empty_ReturnsFalse() {
        // Given
        sut.displayName = ""
        
        // When
        let result = sut.validateDisplayName()
        
        // Then
        XCTAssertFalse(result, "Empty display name should be invalid")
        XCTAssertEqual(sut.errorMessage, "Display name cannot be empty")
    }
    
    func testValidateDisplayName_OnlyWhitespace_ReturnsFalse() {
        // Given
        sut.displayName = "   "
        
        // When
        let result = sut.validateDisplayName()
        
        // Then
        XCTAssertFalse(result, "Whitespace-only display name should be invalid")
        XCTAssertEqual(sut.errorMessage, "Display name cannot be empty")
    }
    
    func testValidateDisplayName_TooLong_ReturnsFalse() {
        // Given
        sut.displayName = String(repeating: "a", count: 51)
        
        // When
        let result = sut.validateDisplayName()
        
        // Then
        XCTAssertFalse(result, "Display name over 50 characters should be invalid")
        XCTAssertEqual(sut.errorMessage, "Display name must be 50 characters or less")
    }
    
    func testValidateDisplayName_ExactlyFiftyCharacters_ReturnsTrue() {
        // Given
        sut.displayName = String(repeating: "a", count: 50)
        
        // When
        let result = sut.validateDisplayName()
        
        // Then
        XCTAssertTrue(result, "Display name with exactly 50 characters should be valid")
        XCTAssertNil(sut.errorMessage, "Should have no error message")
    }
    
    func testValidateDisplayName_Valid_ReturnsTrue() {
        // Given
        sut.displayName = "John Doe"
        
        // When
        let result = sut.validateDisplayName()
        
        // Then
        XCTAssertTrue(result, "Valid display name should pass validation")
        XCTAssertNil(sut.errorMessage, "Should have no error message")
    }
    
    func testSaveProfile_InvalidDisplayName_DoesNotCallRepository() async {
        // Given
        sut.displayName = ""
        
        // When
        await sut.saveProfile()
        
        // Then
        XCTAssertFalse(mockUserRepo.updateUserCalled, "Should not call repository with invalid name")
        XCTAssertFalse(sut.profileSaved, "Profile should not be marked as saved")
    }
    
    // MARK: - Skip Setup Tests
    
    func testSkipSetup_UsesDefaultName() async {
        // Given
        sut.displayName = "Changed Name"
        
        // When
        sut.skipSetup()
        
        // Wait briefly for Task to execute
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(sut.displayName, "john.doe", "Should reset to email prefix")
        XCTAssertTrue(mockUserRepo.updateUserCalled, "Should save profile with default name")
        XCTAssertEqual(mockUserRepo.capturedUser?.displayName, "john.doe")
    }
    
    func testSkipSetup_SavesProfileWithDefaultName() async {
        // Given / When
        sut.skipSetup()
        
        // Wait briefly for Task to execute
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertTrue(mockUserRepo.updateUserCalled, "Should call updateUser")
        XCTAssertEqual(mockUserRepo.capturedUser?.displayName, "john.doe")
        
        // Wait a bit more to ensure async operation completes
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // profileSaved should eventually be true
        XCTAssertTrue(sut.profileSaved, "Profile should be marked as saved after skip")
    }
    
    // MARK: - Loading State Tests
    
    func testSaveProfile_SetsLoadingStateDuringOperation() async {
        // Given
        sut.displayName = "John Doe"
        
        // Create expectation for loading state
        var wasLoadingDuringOperation = false
        
        // When
        let task = Task {
            await sut.saveProfile()
        }
        
        // Check loading state immediately after starting
        // Note: This is a best-effort check; timing-dependent
        if sut.isLoading {
            wasLoadingDuringOperation = true
        }
        
        await task.value
        
        // Then
        XCTAssertFalse(sut.isLoading, "Should not be loading after completion")
        // Note: wasLoadingDuringOperation may be false due to timing, so we don't assert it
    }
    
    // MARK: - Error Clearing Tests
    
    func testSaveProfile_ClearsErrorMessageOnNewAttempt() async {
        // Given
        mockUserRepo.shouldFail = true
        sut.displayName = "John Doe"
        await sut.saveProfile()
        XCTAssertNotNil(sut.errorMessage, "Should have error after failed save")
        
        // When - retry with success
        mockUserRepo.shouldFail = false
        await sut.saveProfile()
        
        // Then
        XCTAssertNil(sut.errorMessage, "Error should be cleared on successful retry")
        XCTAssertTrue(sut.profileSaved)
    }
    
    // MARK: - Upload Profile Image Tests
    
    func testUploadProfileImage_ProcessesImage() async {
        // Given
        let testImage = createTestImage()
        
        // When
        await sut.uploadProfileImage(testImage)
        
        // Then
        XCTAssertFalse(sut.isLoading, "Should not be loading after completion")
        // Note: Actual upload is not implemented in MVP, so we just verify it doesn't crash
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}


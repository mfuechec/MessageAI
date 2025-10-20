import XCTest
@testable import MessageAI

final class UserTests: XCTestCase {
    
    func testUserInitialization() {
        // When: Create user with minimal parameters
        let user = User(
            id: "user-1",
            email: "test@example.com",
            displayName: "Test User"
        )
        
        // Then: Default values should be set correctly
        XCTAssertEqual(user.id, "user-1")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertFalse(user.isOnline)
        XCTAssertNil(user.profileImageURL)
        XCTAssertNil(user.fcmToken)
    }
    
    func testDisplayInitialsTwoWords() {
        // Given: User with two-word name
        let user = User(
            id: "user-1",
            email: "test@example.com",
            displayName: "John Doe"
        )
        
        // Then: Should return first letter of each word
        XCTAssertEqual(user.displayInitials, "JD")
    }
    
    func testDisplayInitialsSingleWord() {
        // Given: User with single-word name
        let user = User(
            id: "user-2",
            email: "test@example.com",
            displayName: "Alice"
        )
        
        // Then: Should return first two letters
        XCTAssertEqual(user.displayInitials, "AL")
    }
    
    func testDisplayInitialsThreeWords() {
        // Given: User with three-word name
        let user = User(
            id: "user-3",
            email: "test@example.com",
            displayName: "Mary Jane Watson"
        )
        
        // Then: Should return first two words' initials
        XCTAssertEqual(user.displayInitials, "MJ")
    }
    
    func testUserCodable() throws {
        // Given: A user entity
        let user = User(
            id: "user-1",
            email: "test@example.com",
            displayName: "Test User",
            isOnline: true
        )
        
        // When: Encode and decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(user)
        
        let decoder = JSONDecoder()
        let decodedUser = try decoder.decode(User.self, from: data)
        
        // Then: Should match original
        XCTAssertEqual(user, decodedUser)
    }
    
    func testUserEquality() {
        // Given: Two users with same properties (using same timestamps)
        let now = Date()
        let user1 = User(
            id: "user-1",
            email: "test@example.com",
            displayName: "Test",
            lastSeen: now,
            createdAt: now
        )
        
        let user2 = User(
            id: "user-1",
            email: "test@example.com",
            displayName: "Test",
            lastSeen: now,
            createdAt: now
        )
        
        // Then: They should be equal
        XCTAssertEqual(user1, user2)
    }
}


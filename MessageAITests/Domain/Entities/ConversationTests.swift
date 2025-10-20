import XCTest
@testable import MessageAI

final class ConversationTests: XCTestCase {
    
    func testConversationInitialization() {
        // When: Create conversation with minimal parameters
        let conversation = Conversation(
            participantIds: ["user-1", "user-2"]
        )
        
        // Then: Default values should be set correctly
        XCTAssertEqual(conversation.participantIds.count, 2)
        XCTAssertTrue(conversation.participantIds.contains("user-1"))
        XCTAssertTrue(conversation.participantIds.contains("user-2"))
        XCTAssertFalse(conversation.isGroup)
        XCTAssertFalse(conversation.isArchived)
        XCTAssertFalse(conversation.isMuted)
        XCTAssertNil(conversation.lastMessage)
    }
    
    func testUnreadCountForUser() {
        // Given: Conversation with unread counts
        var conversation = Conversation(
            participantIds: ["user-1", "user-2"]
        )
        conversation.unreadCounts = ["user-1": 5, "user-2": 0]
        
        // Then: Should return correct counts
        XCTAssertEqual(conversation.unreadCount(for: "user-1"), 5)
        XCTAssertEqual(conversation.unreadCount(for: "user-2"), 0)
        XCTAssertEqual(conversation.unreadCount(for: "user-3"), 0) // Non-existent user
    }
    
    func testCanAddParticipantUnderLimit() {
        // Given: Conversation with 2 participants
        let conversation = Conversation(
            participantIds: ["user-1", "user-2"]
        )
        
        // Then: Should allow adding more
        XCTAssertTrue(conversation.canAddParticipant())
    }
    
    func testCanAddParticipantAtLimit() {
        // Given: Conversation at max capacity (10)
        var conversation = Conversation(
            participantIds: ["user-1", "user-2"]
        )
        conversation.participantIds = Array(repeating: "user", count: 10)
        
        // Then: Should not allow adding more
        XCTAssertFalse(conversation.canAddParticipant())
    }
    
    func testConversationCodable() throws {
        // Given: A conversation entity
        let conversation = Conversation(
            participantIds: ["user-1", "user-2"],
            lastMessage: "Hello",
            isGroup: false
        )
        
        // When: Encode and decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(conversation)
        
        let decoder = JSONDecoder()
        let decodedConversation = try decoder.decode(Conversation.self, from: data)
        
        // Then: IDs should match
        XCTAssertEqual(conversation.id, decodedConversation.id)
        XCTAssertEqual(conversation.participantIds, decodedConversation.participantIds)
        XCTAssertEqual(conversation.lastMessage, decodedConversation.lastMessage)
    }
    
    func testDisplayNameForOneOnOne() {
        // Given: 1-on-1 conversation with users
        let conversation = Conversation(
            participantIds: ["user-1", "user-2"],
            isGroup: false
        )
        
        let user1 = User(id: "user-1", email: "alice@example.com", displayName: "Alice")
        let user2 = User(id: "user-2", email: "bob@example.com", displayName: "Bob")
        
        // When: Get display name for user-1
        let displayName = conversation.displayName(for: "user-1", users: [user1, user2])
        
        // Then: Should show other participant's name
        XCTAssertEqual(displayName, "Bob")
    }
    
    func testDisplayNameForGroupWithCustomName() {
        // Given: Group conversation with custom name
        let conversation = Conversation(
            participantIds: ["user-1", "user-2", "user-3"],
            isGroup: true,
            groupName: "Team Chat"
        )
        
        let users = [
            User(id: "user-1", email: "alice@example.com", displayName: "Alice"),
            User(id: "user-2", email: "bob@example.com", displayName: "Bob"),
            User(id: "user-3", email: "carol@example.com", displayName: "Carol")
        ]
        
        // When: Get display name
        let displayName = conversation.displayName(for: "user-1", users: users)
        
        // Then: Should show group name
        XCTAssertEqual(displayName, "Team Chat")
    }
    
    func testDisplayNameForGroupWithoutCustomName() {
        // Given: Group conversation without custom name
        let conversation = Conversation(
            participantIds: ["user-1", "user-2", "user-3"],
            isGroup: true,
            groupName: nil
        )
        
        let users = [
            User(id: "user-1", email: "alice@example.com", displayName: "Alice"),
            User(id: "user-2", email: "bob@example.com", displayName: "Bob"),
            User(id: "user-3", email: "carol@example.com", displayName: "Carol")
        ]
        
        // When: Get display name
        let displayName = conversation.displayName(for: "user-1", users: users)
        
        // Then: Should show concatenated participant names
        XCTAssertEqual(displayName, "Alice, Bob, Carol")
    }
}


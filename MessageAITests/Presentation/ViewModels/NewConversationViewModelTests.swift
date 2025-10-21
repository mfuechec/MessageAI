//
//  NewConversationViewModelTests.swift
//  MessageAITests
//
//  Created by Dev Agent (James) on 10/21/25.
//  Story 2.0: Start New Conversation with Duplicate Prevention
//

import XCTest
import Combine
@testable import MessageAI

@MainActor
final class NewConversationViewModelTests: XCTestCase {
    
    var sut: NewConversationViewModel!
    var mockUserRepository: MockUserRepository!
    var mockConversationRepository: MockConversationRepository!
    var mockAuthRepository: MockAuthRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockUserRepository = MockUserRepository()
        mockConversationRepository = MockConversationRepository()
        mockAuthRepository = MockAuthRepository()
        cancellables = Set<AnyCancellable>()
        
        sut = NewConversationViewModel(
            userRepository: mockUserRepository,
            conversationRepository: mockConversationRepository,
            authRepository: mockAuthRepository
        )
    }
    
    override func tearDown() {
        sut = nil
        mockUserRepository = nil
        mockConversationRepository = nil
        mockAuthRepository = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Load Users Tests
    
    func testLoadUsers_Success() async throws {
        // Given: Mock users and current user
        let currentUser = User(id: "current-user", email: "current@test.com", displayName: "Current User")
        let user1 = User(id: "user-1", email: "user1@test.com", displayName: "Alice")
        let user2 = User(id: "user-2", email: "user2@test.com", displayName: "Bob")
        
        mockAuthRepository.mockUser = currentUser
        mockUserRepository.mockUsers = [currentUser, user1, user2]
        
        // When: Load users
        await sut.loadUsers()
        
        // Then: Current user excluded, others included
        XCTAssertTrue(mockUserRepository.getAllUsersCalled)
        XCTAssertEqual(sut.users.count, 2)
        XCTAssertFalse(sut.users.contains(where: { $0.id == currentUser.id }))
        XCTAssertTrue(sut.users.contains(where: { $0.id == user1.id }))
        XCTAssertTrue(sut.users.contains(where: { $0.id == user2.id }))
        XCTAssertEqual(sut.filteredUsers.count, 2)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testLoadUsers_Failure() async throws {
        // Given: Mock repository configured to fail
        mockUserRepository.shouldFail = true
        mockAuthRepository.mockUser = User(id: "current", email: "current@test.com", displayName: "Current")
        
        // When: Load users
        await sut.loadUsers()
        
        // Then: Error message set
        XCTAssertTrue(mockUserRepository.getAllUsersCalled)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.users.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }
    
    // MARK: - Search Filter Tests
    
    func testSearchFilter_ByName() async throws {
        // Given: Users loaded with different names
        let currentUser = User(id: "current", email: "current@test.com", displayName: "Current")
        let alice = User(id: "user-1", email: "alice@test.com", displayName: "Alice Smith")
        let bob = User(id: "user-2", email: "bob@test.com", displayName: "Bob Jones")
        
        mockAuthRepository.mockUser = currentUser
        mockUserRepository.mockUsers = [currentUser, alice, bob]
        
        await sut.loadUsers()
        
        // When: Search by name
        sut.searchText = "Alice"
        
        // Then: Wait for debounce and check filtered results
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms for 300ms debounce + margin
        
        XCTAssertEqual(sut.filteredUsers.count, 1)
        XCTAssertEqual(sut.filteredUsers.first?.displayName, "Alice Smith")
    }
    
    func testSearchFilter_ByEmail() async throws {
        // Given: Users loaded
        let currentUser = User(id: "current", email: "current@test.com", displayName: "Current")
        let alice = User(id: "user-1", email: "alice@test.com", displayName: "Alice")
        let bob = User(id: "user-2", email: "bob@example.com", displayName: "Bob")
        
        mockAuthRepository.mockUser = currentUser
        mockUserRepository.mockUsers = [currentUser, alice, bob]
        
        await sut.loadUsers()
        
        // When: Search by email domain
        sut.searchText = "example"
        
        // Then: Wait for debounce
        try await Task.sleep(nanoseconds: 400_000_000)
        
        XCTAssertEqual(sut.filteredUsers.count, 1)
        XCTAssertEqual(sut.filteredUsers.first?.email, "bob@example.com")
    }
    
    func testSearchFilter_Empty() async throws {
        // Given: Users loaded
        let currentUser = User(id: "current", email: "current@test.com", displayName: "Current")
        let alice = User(id: "user-1", email: "alice@test.com", displayName: "Alice")
        let bob = User(id: "user-2", email: "bob@test.com", displayName: "Bob")
        
        mockAuthRepository.mockUser = currentUser
        mockUserRepository.mockUsers = [currentUser, alice, bob]
        
        await sut.loadUsers()
        
        // When: Set search text then clear it
        sut.searchText = "Alice"
        try await Task.sleep(nanoseconds: 400_000_000)
        
        sut.searchText = ""
        try await Task.sleep(nanoseconds: 400_000_000)
        
        // Then: All users shown
        XCTAssertEqual(sut.filteredUsers.count, 2) // Excluding current user
    }
    
    // MARK: - Select User Tests
    
    func testSelectUser_Success() async throws {
        // Given: Mock conversation ready
        let currentUser = User(id: "current", email: "current@test.com", displayName: "Current")
        let selectedUser = User(id: "user-1", email: "user1@test.com", displayName: "Alice")
        let mockConversation = Conversation(
            id: "conv-1",
            participantIds: ["current", "user-1"],
            createdAt: Date(),
            isGroup: false
        )
        
        mockAuthRepository.mockUser = currentUser
        mockConversationRepository.mockConversation = mockConversation
        
        // When: Select user
        await sut.selectUser(selectedUser)
        
        // Then: Conversation created and selected
        XCTAssertTrue(mockConversationRepository.getOrCreateConversationCalled)
        XCTAssertNotNil(sut.selectedConversation)
        XCTAssertEqual(sut.selectedConversation?.id, "conv-1")
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testSelectUser_SelfConversation() async throws {
        // Given: Current user
        let currentUser = User(id: "current", email: "current@test.com", displayName: "Current")
        mockAuthRepository.mockUser = currentUser
        
        // When: Try to select self
        await sut.selectUser(currentUser)
        
        // Then: Error message set, no conversation created
        XCTAssertFalse(mockConversationRepository.getOrCreateConversationCalled)
        XCTAssertNil(sut.selectedConversation)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage?.contains("yourself") ?? false)
    }
    
    func testSelectUser_Failure() async throws {
        // Given: Repository configured to fail
        let currentUser = User(id: "current", email: "current@test.com", displayName: "Current")
        let selectedUser = User(id: "user-1", email: "user1@test.com", displayName: "Alice")
        
        mockAuthRepository.mockUser = currentUser
        mockConversationRepository.shouldFail = true
        mockConversationRepository.mockError = RepositoryError.networkError(
            NSError(domain: "test", code: -1)
        )
        
        // When: Select user
        await sut.selectUser(selectedUser)
        
        // Then: Error message set
        XCTAssertTrue(mockConversationRepository.getOrCreateConversationCalled)
        XCTAssertNil(sut.selectedConversation)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testSearchDebounce() async throws {
        // Given: Users loaded
        let currentUser = User(id: "current", email: "current@test.com", displayName: "Current")
        let alice = User(id: "user-1", email: "alice@test.com", displayName: "Alice")
        
        mockAuthRepository.mockUser = currentUser
        mockUserRepository.mockUsers = [currentUser, alice]
        
        await sut.loadUsers()
        
        // When: Rapid search text changes
        sut.searchText = "A"
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        sut.searchText = "Al"
        try await Task.sleep(nanoseconds: 100_000_000)
        
        sut.searchText = "Ali"
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: Filter not applied yet (still debouncing)
        XCTAssertEqual(sut.filteredUsers.count, 1) // Still showing all users
        
        // Wait for debounce to complete
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Now filter should be applied
        XCTAssertEqual(sut.filteredUsers.count, 1)
        XCTAssertEqual(sut.filteredUsers.first?.displayName, "Alice")
    }
    
    // MARK: - Group Conversation Tests (Story 2.1)
    
    func testSelectMultipleUsers_ThreeUsers_Success() async throws {
        // Given: Current user and 3 selected users
        let currentUser = User(id: "current", email: "current@test.com", displayName: "Current")
        let user1 = User(id: "user-1", email: "user1@test.com", displayName: "Alice")
        let user2 = User(id: "user-2", email: "user2@test.com", displayName: "Bob")
        let user3 = User(id: "user-3", email: "user3@test.com", displayName: "Charlie")
        
        let groupConversation = Conversation(
            id: "group-conv-1",
            participantIds: ["current", "user-1", "user-2", "user-3"],
            lastMessage: nil,
            lastMessageTimestamp: nil,
            createdAt: Date(),
            isGroup: true
        )
        
        mockAuthRepository.mockUser = currentUser
        mockConversationRepository.mockConversation = groupConversation
        
        // When: Select multiple users
        await sut.selectMultipleUsers([user1, user2, user3])
        
        // Then: Group conversation created
        XCTAssertTrue(mockConversationRepository.getOrCreateConversationCalled)
        XCTAssertEqual(mockConversationRepository.capturedParticipantIds?.count, 4) // Current + 3 users
        XCTAssertEqual(sut.selectedConversation?.id, groupConversation.id)
        XCTAssertTrue(sut.selectedConversation?.isGroup ?? false)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testSelectMultipleUsers_TwoUsers_Success() async throws {
        // Given: Current user and 2 selected users (now valid)
        let currentUser = User(id: "current", email: "current@test.com", displayName: "Current")
        let user1 = User(id: "user-1", email: "user1@test.com", displayName: "Alice")
        let user2 = User(id: "user-2", email: "user2@test.com", displayName: "Bob")
        
        let conversation = Conversation(
            id: "conv-1",
            participantIds: ["current", "user-1", "user-2"],
            lastMessage: nil,
            lastMessageTimestamp: nil,
            createdAt: Date(),
            isGroup: true
        )
        
        mockAuthRepository.mockUser = currentUser
        mockConversationRepository.mockConversation = conversation
        
        // When: Select 2 users
        await sut.selectMultipleUsers([user1, user2])
        
        // Then: Conversation created successfully
        XCTAssertTrue(mockConversationRepository.getOrCreateConversationCalled)
        XCTAssertEqual(mockConversationRepository.capturedParticipantIds?.count, 3) // Current + 2 users
        XCTAssertEqual(sut.selectedConversation?.id, conversation.id)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testSelectMultipleUsers_ManyUsers_Success() async throws {
        // Given: Current user and many selected users (no max limit)
        let currentUser = User(id: "current", email: "current@test.com", displayName: "Current")
        let selectedUsers = (1...15).map { User(id: "user-\($0)", email: "user\($0)@test.com", displayName: "User \($0)") }
        
        let conversation = Conversation(
            id: "large-group",
            participantIds: ["current"] + selectedUsers.map { $0.id },
            lastMessage: nil,
            lastMessageTimestamp: nil,
            createdAt: Date(),
            isGroup: true
        )
        
        mockAuthRepository.mockUser = currentUser
        mockConversationRepository.mockConversation = conversation
        
        // When: Select many users
        await sut.selectMultipleUsers(selectedUsers)
        
        // Then: Conversation created successfully
        XCTAssertTrue(mockConversationRepository.getOrCreateConversationCalled)
        XCTAssertEqual(mockConversationRepository.capturedParticipantIds?.count, 16) // Current + 15 users
        XCTAssertEqual(sut.selectedConversation?.id, conversation.id)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testSelectMultipleUsers_IncludesSelf_ShowsError() async throws {
        // Given: Selected users include current user (should be prevented)
        let currentUser = User(id: "current", email: "current@test.com", displayName: "Current")
        let user1 = User(id: "user-1", email: "user1@test.com", displayName: "Alice")
        let user2 = User(id: "user-2", email: "user2@test.com", displayName: "Bob")
        
        mockAuthRepository.mockUser = currentUser
        
        // When: Try to select users including self
        await sut.selectMultipleUsers([currentUser, user1, user2])
        
        // Then: Error message shown
        XCTAssertFalse(mockConversationRepository.getOrCreateConversationCalled)
        XCTAssertNil(sut.selectedConversation)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage?.contains("yourself") ?? false)
    }
    
    func testSelectMultipleUsers_RepositoryError() async throws {
        // Given: Repository will fail
        let currentUser = User(id: "current", email: "current@test.com", displayName: "Current")
        let user1 = User(id: "user-1", email: "user1@test.com", displayName: "Alice")
        let user2 = User(id: "user-2", email: "user2@test.com", displayName: "Bob")
        let user3 = User(id: "user-3", email: "user3@test.com", displayName: "Charlie")
        
        mockAuthRepository.mockUser = currentUser
        mockConversationRepository.shouldFail = true
        mockConversationRepository.mockError = RepositoryError.networkError(
            NSError(domain: "test", code: -1)
        )
        
        // When: Select multiple users
        await sut.selectMultipleUsers([user1, user2, user3])
        
        // Then: Error message set
        XCTAssertTrue(mockConversationRepository.getOrCreateConversationCalled)
        XCTAssertNil(sut.selectedConversation)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }
}


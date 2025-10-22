import XCTest
@testable import MessageAI

@MainActor
final class AppStateTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        // Clear AppState after each test (singleton persists across tests)
        AppState.shared.clearState()
    }

    func testAppStateSingleton() {
        // Given & When
        let instance1 = AppState.shared
        let instance2 = AppState.shared

        // Then
        XCTAssertTrue(instance1 === instance2, "AppState.shared should return same instance")
    }

    func testAppStateClearState() async throws {
        // Given
        let appState = AppState.shared
        appState.currentlyViewingConversationId = "test-conversation-123"

        // When
        appState.clearState()

        // Then
        XCTAssertNil(appState.currentlyViewingConversationId, "currentlyViewingConversationId should be nil after clearState()")
    }

    func testCurrentlyViewingConversationId_InitiallyNil() {
        // Given & When
        let appState = AppState.shared

        // Then
        XCTAssertNil(appState.currentlyViewingConversationId, "currentlyViewingConversationId should be nil initially")
    }

    func testCurrentlyViewingConversationId_CanBeSet() {
        // Given
        let appState = AppState.shared
        let conversationId = "conv-456"

        // When
        appState.currentlyViewingConversationId = conversationId

        // Then
        XCTAssertEqual(appState.currentlyViewingConversationId, conversationId)
    }
}

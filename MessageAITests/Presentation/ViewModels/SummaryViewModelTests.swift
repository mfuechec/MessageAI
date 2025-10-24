//
//  SummaryViewModelTests.swift
//  MessageAITests
//
//  Created by Claude Code on 10/23/25.
//  Story 3.2: Thread Summarization Feature
//

import XCTest
@testable import MessageAI

@MainActor
final class SummaryViewModelTests: XCTestCase {
    var mockAIService: MockAIService!
    var viewModel: SummaryViewModel!

    override func setUp() {
        super.setUp()
        mockAIService = MockAIService()
        viewModel = SummaryViewModel(
            conversationId: "test-conversation",
            aiService: mockAIService
        )
    }

    override func tearDown() {
        viewModel = nil
        mockAIService = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        // Assert initial state
        XCTAssertNil(viewModel.summary, "Summary should be nil initially")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertNil(viewModel.errorMessage, "Error message should be nil initially")
        XCTAssertFalse(viewModel.isCached, "Should not be cached initially")
    }

    // MARK: - Load Summary Tests

    func testLoadSummarySuccess() async {
        // Arrange
        let expectedSummary = ThreadSummary(
            summary: "Test summary",
            keyPoints: ["Point 1", "Point 2"],
            priorityMessages: [],
            participants: ["Alice", "Bob"],
            dateRange: "Oct 1 - Oct 23",
            generatedAt: Date(),
            cached: false,
            messagesSinceCache: 0
        )
        mockAIService.mockSummary = expectedSummary

        // Act
        await viewModel.loadSummary()

        // Assert
        XCTAssertEqual(mockAIService.summarizeThreadCallCount, 1, "Should call summarizeThread once")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
        XCTAssertNil(viewModel.errorMessage, "Should have no error message")
        XCTAssertNotNil(viewModel.summary, "Summary should be loaded")
        XCTAssertEqual(viewModel.summary?.summary, "Test summary")
        XCTAssertEqual(viewModel.summary?.keyPoints.count, 2)
        XCTAssertEqual(viewModel.summary?.participants.count, 2)
    }

    func testLoadSummaryCached() async {
        // Arrange
        let cachedSummary = ThreadSummary(
            summary: "Cached summary",
            keyPoints: [],
            priorityMessages: [],
            participants: [],
            dateRange: "",
            generatedAt: Date(),
            cached: true,
            messagesSinceCache: 5  // Test staleness indicator
        )
        mockAIService.mockSummary = cachedSummary

        // Act
        await viewModel.loadSummary()

        // Assert
        XCTAssertTrue(viewModel.isCached, "Should indicate cached result")
        XCTAssertNotNil(viewModel.summary)
    }

    func testLoadSummaryFailure_RateLimitExceeded() async {
        // Arrange
        mockAIService.shouldFail = true
        mockAIService.errorToThrow = .rateLimitExceeded

        // Act
        await viewModel.loadSummary()

        // Assert
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after error")
        XCTAssertNil(viewModel.summary, "Summary should be nil on error")
        XCTAssertNotNil(viewModel.errorMessage, "Should have error message")
        XCTAssertTrue(
            viewModel.errorMessage?.contains("100 AI requests") ?? false,
            "Error message should mention rate limit"
        )
    }

    func testLoadSummaryFailure_ServiceUnavailable() async {
        // Arrange
        mockAIService.shouldFail = true
        mockAIService.errorToThrow = .serviceUnavailable

        // Act
        await viewModel.loadSummary()

        // Assert
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(
            viewModel.errorMessage?.contains("temporarily unavailable") ?? false,
            "Error message should mention service unavailable"
        )
    }

    func testLoadSummaryFailure_Timeout() async {
        // Arrange
        mockAIService.shouldFail = true
        mockAIService.errorToThrow = .timeout

        // Act
        await viewModel.loadSummary()

        // Assert
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(
            viewModel.errorMessage?.contains("too long") ?? false,
            "Error message should mention timeout"
        )
    }

    // MARK: - Regenerate Summary Tests

    func testRegenerateSummary() async {
        // Arrange - Load initial summary
        let initialSummary = ThreadSummary(
            summary: "Initial summary",
            keyPoints: [],
            priorityMessages: [],
            participants: [],
            dateRange: "",
            generatedAt: Date().addingTimeInterval(-3600), // 1 hour ago
            cached: true,
            messagesSinceCache: 3
        )
        mockAIService.mockSummary = initialSummary
        await viewModel.loadSummary()

        XCTAssertNotNil(viewModel.summary)
        XCTAssertEqual(mockAIService.summarizeThreadCallCount, 1)

        // Arrange - New summary for regeneration
        let newSummary = ThreadSummary(
            summary: "Regenerated summary",
            keyPoints: ["New point"],
            priorityMessages: [],
            participants: ["Charlie"],
            dateRange: "Oct 23",
            generatedAt: Date(),
            cached: false,
            messagesSinceCache: 0  // Fresh summary
        )
        mockAIService.mockSummary = newSummary

        // Act
        await viewModel.regenerateSummary()

        // Assert
        XCTAssertEqual(mockAIService.summarizeThreadCallCount, 2, "Should call summarizeThread again")
        XCTAssertNotNil(viewModel.summary)
        XCTAssertEqual(viewModel.summary?.summary, "Regenerated summary")
        XCTAssertFalse(viewModel.isCached, "Regenerated summary should not be from cache")
    }

    // MARK: - Clear Summary Tests

    func testClearSummary() async {
        // Arrange - Load a summary first
        let summary = ThreadSummary(
            summary: "Test",
            keyPoints: [],
            priorityMessages: [],
            participants: [],
            dateRange: "",
            generatedAt: Date(),
            cached: false,
            messagesSinceCache: 0
        )
        mockAIService.mockSummary = summary
        await viewModel.loadSummary()

        XCTAssertNotNil(viewModel.summary)

        // Act
        viewModel.clearSummary()

        // Assert
        XCTAssertNil(viewModel.summary, "Summary should be cleared")
        XCTAssertNil(viewModel.errorMessage, "Error message should be cleared")
    }

    // MARK: - Generated At Text Tests

    func testGeneratedAtText_JustNow() {
        // Arrange
        let summary = ThreadSummary(
            summary: "Test",
            keyPoints: [],
            priorityMessages: [],
            participants: [],
            dateRange: "",
            generatedAt: Date().addingTimeInterval(-30), // 30 seconds ago
            cached: false,
            messagesSinceCache: 0
        )
        mockAIService.mockSummary = summary

        // Act
        Task {
            await viewModel.loadSummary()
        }

        // Wait for async task
        let expectation = expectation(description: "Load summary")
        Task {
            await viewModel.loadSummary()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert
        XCTAssertTrue(
            viewModel.generatedAtText.contains("just now"),
            "Should show 'just now' for recent summaries"
        )
    }

    func testGeneratedAtText_MinutesAgo() {
        // Arrange
        let summary = ThreadSummary(
            summary: "Test",
            keyPoints: [],
            priorityMessages: [],
            participants: [],
            dateRange: "",
            generatedAt: Date().addingTimeInterval(-300), // 5 minutes ago
            cached: false,
            messagesSinceCache: 0
        )
        mockAIService.mockSummary = summary

        // Act & Assert
        let expectation = expectation(description: "Load summary")
        Task {
            await viewModel.loadSummary()
            XCTAssertTrue(
                self.viewModel.generatedAtText.contains("minutes ago"),
                "Should show 'minutes ago' format"
            )
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testGeneratedAtText_HoursAgo() {
        // Arrange
        let summary = ThreadSummary(
            summary: "Test",
            keyPoints: [],
            priorityMessages: [],
            participants: [],
            dateRange: "",
            generatedAt: Date().addingTimeInterval(-7200), // 2 hours ago
            cached: false,
            messagesSinceCache: 0
        )
        mockAIService.mockSummary = summary

        // Act & Assert
        let expectation = expectation(description: "Load summary")
        Task {
            await viewModel.loadSummary()
            XCTAssertTrue(
                self.viewModel.generatedAtText.contains("hours ago") ||
                self.viewModel.generatedAtText.contains("hour ago"),
                "Should show 'hours ago' format"
            )
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Loading State Tests

    func testLoadingStateTransitions() async {
        // Arrange
        mockAIService.mockSummary = ThreadSummary(
            summary: "Test",
            keyPoints: [],
            priorityMessages: [],
            participants: [],
            dateRange: "",
            generatedAt: Date(),
            cached: false,
            messagesSinceCache: 0
        )
        mockAIService.simulateDelay = 0.1 // Simulate network delay

        // Initial state
        XCTAssertFalse(viewModel.isLoading)

        // Start loading
        let loadTask = Task {
            await viewModel.loadSummary()
        }

        // Should be loading immediately after starting
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        XCTAssertTrue(viewModel.isLoading, "Should be loading during async operation")

        // Wait for completion
        await loadTask.value

        // Should not be loading after completion
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
    }
}

// MARK: - Mock AI Service

@MainActor
class MockAIService: AIServiceProtocol {
    var mockSummary: ThreadSummary?
    var shouldFail = false
    var errorToThrow: AIServiceError = .unknown("Mock error")
    var summarizeThreadCallCount = 0
    var simulateDelay: TimeInterval = 0

    func summarizeThread(conversationId: String, messageIds: [String]?, bypassCache: Bool) async throws -> ThreadSummary {
        summarizeThreadCallCount += 1

        if simulateDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulateDelay * 1_000_000_000))
        }

        if shouldFail {
            throw errorToThrow
        }

        guard let summary = mockSummary else {
            throw AIServiceError.unknown("No mock summary configured")
        }

        return summary
    }

    func extractActionItems(conversationId: String, messageIds: [String]?) async throws -> [AIActionItem] {
        []
    }

    func generateSmartSearchResults(query: String, conversationIds: [String]?) async throws -> [AISearchResult] {
        []
    }
}

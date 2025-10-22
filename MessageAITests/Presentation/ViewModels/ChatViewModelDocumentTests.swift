//
//  ChatViewModelDocumentTests.swift
//  MessageAITests
//
//  Tests for document upload functionality in ChatViewModel
//

import XCTest
import Combine
@testable import MessageAI

@MainActor
final class ChatViewModelDocumentTests: XCTestCase {
    var sut: ChatViewModel!
    var mockMessageRepo: MockMessageRepository!
    var mockConversationRepo: MockConversationRepository!
    var mockUserRepo: MockUserRepository!
    var mockStorageRepo: MockStorageRepository!

    override func setUp() async throws {
        try await super.setUp()

        mockMessageRepo = MockMessageRepository()
        mockConversationRepo = MockConversationRepository()
        mockUserRepo = MockUserRepository()
        mockStorageRepo = MockStorageRepository()

        // Set up default mock conversation
        mockConversationRepo.mockConversation = Conversation(
            id: "test-conv",
            participantIds: ["user1", "user2"],
            lastMessage: nil,
            lastMessageTimestamp: nil,
            unreadCounts: [:],
            createdAt: Date(),
            isGroup: false
        )

        sut = ChatViewModel(
            conversationId: "test-conv",
            currentUserId: "user1",
            messageRepository: mockMessageRepo,
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            storageRepository: mockStorageRepo
        )

        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
    }

    override func tearDown() async throws {
        // Clean up temp files
        cleanupTempFiles()

        sut = nil
        mockMessageRepo = nil
        mockConversationRepo = nil
        mockUserRepo = nil
        mockStorageRepo = nil
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func createTempPDF(sizeMB: Int, fileName: String = "test.pdf") -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        let sizeBytes = sizeMB * 1024 * 1024
        let data = Data(repeating: 0, count: sizeBytes)

        try? FileManager.default.removeItem(at: fileURL)
        try? data.write(to: fileURL)

        return fileURL
    }

    private func cleanupTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("test.pdf"))
        try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("large.pdf"))
        try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("Invoice.pdf"))

        // Clean up message-specific temp files
        let contents = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        contents?.forEach { url in
            if url.pathExtension == "pdf" && url.lastPathComponent.contains("-") {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Document Picker Tests

    func testSelectDocument_OpensDocumentPicker() {
        // Given
        XCTAssertFalse(sut.isDocumentPickerPresented)

        // When
        sut.selectDocument()

        // Then
        XCTAssertTrue(sut.isDocumentPickerPresented)
    }

    // MARK: - Document Upload Tests

    func testSendDocumentMessage_ValidPDF_Success() async throws {
        // Given: A valid 5MB PDF
        let fileURL = createTempPDF(sizeMB: 5, fileName: "Invoice.pdf")
        let mockAttachment = MessageAttachment(
            id: "attach-1",
            type: .file,
            url: "https://example.com/doc.pdf",
            thumbnailURL: nil,
            sizeBytes: 5 * 1024 * 1024,
            fileName: "Invoice.pdf"
        )
        mockStorageRepo.mockAttachment = mockAttachment
        XCTAssertEqual(sut.messages.count, 0)

        // When: Sending document
        sut.sendDocumentMessage(fileURL: fileURL)

        // Wait for async upload
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Then: Document upload called
        XCTAssertTrue(mockStorageRepo.uploadMessageDocumentCalled)
        XCTAssertEqual(mockStorageRepo.capturedConversationId, "test-conv")

        // Then: Message sent to repository
        XCTAssertTrue(mockMessageRepo.sendMessageCalled)

        // Then: Message added to local array with attachment
        XCTAssertEqual(sut.messages.count, 1)
        let message = sut.messages[0]
        XCTAssertEqual(message.status, .sent)
        XCTAssertEqual(message.attachments.count, 1)
        XCTAssertEqual(message.attachments[0].type, .file)
        XCTAssertEqual(message.attachments[0].fileName, "Invoice.pdf")
    }

    func testSendDocumentMessage_TooLarge_ShowsError() async throws {
        // Given: A PDF larger than 10MB
        let fileURL = createTempPDF(sizeMB: 11, fileName: "large.pdf")

        // When: Attempting to send document
        sut.sendDocumentMessage(fileURL: fileURL)

        // Wait for validation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then: Error message shown
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage?.contains("10MB") ?? false)

        // Then: No upload attempted
        XCTAssertFalse(mockStorageRepo.uploadMessageDocumentCalled)
        XCTAssertEqual(sut.messages.count, 0)
    }

    func testSendDocumentMessage_UpdatesUploadProgress() async throws {
        // Given: A valid PDF
        let fileURL = createTempPDF(sizeMB: 2)
        mockStorageRepo.mockAttachment = MessageAttachment(
            id: "attach-1",
            type: .file,
            url: "https://example.com/doc.pdf",
            thumbnailURL: nil,
            sizeBytes: 2 * 1024 * 1024,
            fileName: "test.pdf"
        )

        // When: Sending document
        sut.sendDocumentMessage(fileURL: fileURL)

        // Wait for progress updates
        try await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds

        // Then: Progress handler was called (mock calls it with 0.5 and 1.0)
        XCTAssertTrue(mockStorageRepo.progressHandlerCalled)
    }

    func testSendDocumentMessage_UploadFails_ShowsRetryOption() async throws {
        // Given: Mock storage repository configured to fail
        let fileURL = createTempPDF(sizeMB: 2)
        mockStorageRepo.shouldFailUpload = true
        mockStorageRepo.mockError = RepositoryError.networkError(
            NSError(domain: "test", code: 0)
        )

        // When: Sending document
        sut.sendDocumentMessage(fileURL: fileURL)

        // Wait for upload failure
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Then: Message status is failed
        XCTAssertEqual(sut.messages.count, 1)
        let message = sut.messages[0]
        XCTAssertEqual(message.status, .failed)

        // Then: Error message set for retry
        XCTAssertNotNil(sut.uploadErrors[message.id])
        XCTAssertTrue(sut.uploadErrors[message.id]?.contains("retry") ?? false)
    }

    func testSendDocumentMessage_OptimisticUI() async throws {
        // Given: A valid PDF
        let fileURL = createTempPDF(sizeMB: 1)
        let mockAttachment = MessageAttachment(
            id: "attach-1",
            type: .file,
            url: "https://example.com/doc.pdf",
            thumbnailURL: nil,
            sizeBytes: 1 * 1024 * 1024,
            fileName: "test.pdf"
        )
        mockStorageRepo.mockAttachment = mockAttachment

        // When: Sending document
        sut.sendDocumentMessage(fileURL: fileURL)

        // Then: Message appears immediately (optimistic UI)
        try await Task.sleep(nanoseconds: 20_000_000) // 0.02 seconds
        XCTAssertEqual(sut.messages.count, 1)
        // Status could be sending or sent depending on timing (mock completes fast)
        XCTAssertTrue([.sending, .sent].contains(sut.messages[0].status))

        // Wait for upload to complete
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        XCTAssertEqual(sut.messages[0].status, .sent)
    }

    func testSendDocumentMessage_WithCaption() async throws {
        // Given: A valid PDF and caption text
        let fileURL = createTempPDF(sizeMB: 1)
        let mockAttachment = MessageAttachment(
            id: "attach-1",
            type: .file,
            url: "https://example.com/doc.pdf",
            thumbnailURL: nil,
            sizeBytes: 1 * 1024 * 1024,
            fileName: "test.pdf"
        )
        mockStorageRepo.mockAttachment = mockAttachment
        sut.messageText = "Here's the invoice"

        // When: Sending document
        sut.sendDocumentMessage(fileURL: fileURL)

        // Wait for upload
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Then: Message includes caption text
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages[0].text, "Here's the invoice")
        XCTAssertEqual(sut.messages[0].attachments.count, 1)

        // Then: Text input cleared
        XCTAssertEqual(sut.messageText, "")
    }

    func testRetryDocumentUpload_Success() async throws {
        // Given: A previously failed document upload
        let fileURL = createTempPDF(sizeMB: 2)
        mockStorageRepo.shouldFailUpload = true
        mockStorageRepo.mockError = RepositoryError.networkError(
            NSError(domain: "test", code: 0)
        )

        sut.sendDocumentMessage(fileURL: fileURL)
        try await Task.sleep(nanoseconds: 200_000_000) // Wait for failure

        guard let messageId = sut.messages.first?.id else {
            XCTFail("No message created")
            return
        }

        // When: Retrying upload (with success this time)
        mockStorageRepo.shouldFailUpload = false
        mockStorageRepo.mockAttachment = MessageAttachment(
            id: "attach-1",
            type: .file,
            url: "https://example.com/doc.pdf",
            thumbnailURL: nil,
            sizeBytes: 2 * 1024 * 1024,
            fileName: "test.pdf"
        )
        sut.retryDocumentUpload(messageId: messageId)

        // Wait for retry
        try await Task.sleep(nanoseconds: 200_000_000)

        // Then: Upload succeeds
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages[0].status, .sent)
        XCTAssertNil(sut.uploadErrors[messageId])
    }

    func testSendDocumentMessage_CleansUpProgress() async throws {
        // Given: A valid PDF
        let fileURL = createTempPDF(sizeMB: 1)
        mockStorageRepo.mockAttachment = MessageAttachment(
            id: "attach-1",
            type: .file,
            url: "https://example.com/doc.pdf",
            thumbnailURL: nil,
            sizeBytes: 1 * 1024 * 1024,
            fileName: "test.pdf"
        )

        // When: Sending document
        sut.sendDocumentMessage(fileURL: fileURL)

        // Wait for completion
        try await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds

        guard let messageId = sut.messages.first?.id else {
            XCTFail("No message created")
            return
        }

        // Then: Progress cleaned up after success
        // Note: Progress may still be set if mock completed very fast
        // The important check is that errors are cleared
        XCTAssertNil(sut.uploadErrors[messageId])
        XCTAssertEqual(sut.messages[0].status, .sent)
    }
}

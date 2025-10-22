//
//  MockStorageRepository.swift
//  MessageAITests
//
//  Mock implementation of StorageRepositoryProtocol for testing
//

import Foundation
import UIKit
@testable import MessageAI

class MockStorageRepository: StorageRepositoryProtocol {
    // MARK: - Tracking Properties

    var uploadProfileImageCalled = false
    var uploadMessageImageCalled = false
    var cancelUploadCalled = false
    var deleteFileCalled = false
    var capturedImage: UIImage?
    var capturedUserId: String?
    var capturedConversationId: String?
    var capturedMessageId: String?
    var capturedPath: String?
    var progressHandlerCalled = false

    // MARK: - Configuration Properties

    var shouldFailUpload = false
    var shouldFailDelete = false
    var mockDownloadURL: String = "https://example.com/message-image.jpg"
    var mockAttachment: MessageAttachment?
    var mockError: Error = RepositoryError.networkError(NSError(domain: "test", code: 0))
    
    // MARK: - Protocol Methods
    
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        uploadProfileImageCalled = true
        capturedImage = image
        capturedUserId = userId
        
        if shouldFailUpload {
            throw mockError
        }
        
        return mockDownloadURL
    }
    
    func uploadMessageImage(
        _ image: UIImage,
        conversationId: String,
        messageId: String,
        progressHandler: ((Double) -> Void)?
    ) async throws -> MessageAttachment {
        uploadMessageImageCalled = true
        capturedImage = image
        capturedConversationId = conversationId
        capturedMessageId = messageId

        // Call progress handler to test progress tracking
        if let handler = progressHandler {
            handler(0.5)
            handler(1.0)
            progressHandlerCalled = true
        }

        if shouldFailUpload {
            throw mockError
        }

        // Return mock attachment or configured one
        if let mockAttachment = mockAttachment {
            return mockAttachment
        }

        return MessageAttachment(
            id: UUID().uuidString,
            type: .image,
            url: mockDownloadURL,
            thumbnailURL: nil,
            sizeBytes: 1024 * 500  // 500KB
        )
    }

    func cancelUpload(for messageId: String) async throws {
        cancelUploadCalled = true
        capturedMessageId = messageId
    }

    func deleteFile(at path: String) async throws {
        deleteFileCalled = true
        capturedPath = path

        if shouldFailDelete {
            throw mockError
        }
    }

    // MARK: - Test Helpers
    
    func reset() {
        uploadProfileImageCalled = false
        uploadMessageImageCalled = false
        cancelUploadCalled = false
        deleteFileCalled = false
        capturedImage = nil
        capturedUserId = nil
        capturedConversationId = nil
        capturedMessageId = nil
        capturedPath = nil
        progressHandlerCalled = false
        shouldFailUpload = false
        shouldFailDelete = false
        mockDownloadURL = "https://example.com/message-image.jpg"
        mockAttachment = nil
        mockError = RepositoryError.networkError(NSError(domain: "test", code: 0))
    }
}


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
    var deleteFileCalled = false
    var capturedImage: UIImage?
    var capturedUserId: String?
    var capturedPath: String?
    
    // MARK: - Configuration Properties
    
    var shouldFailUpload = false
    var shouldFailDelete = false
    var mockDownloadURL: String = "https://example.com/profile.jpg"
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
        deleteFileCalled = false
        capturedImage = nil
        capturedUserId = nil
        capturedPath = nil
        shouldFailUpload = false
        shouldFailDelete = false
        mockDownloadURL = "https://example.com/profile.jpg"
        mockError = RepositoryError.networkError(NSError(domain: "test", code: 0))
    }
}


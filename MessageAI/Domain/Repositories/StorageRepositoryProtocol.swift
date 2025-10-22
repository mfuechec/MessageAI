//
//  StorageRepositoryProtocol.swift
//  MessageAI
//
//  Protocol for file storage operations
//

import Foundation
import UIKit

/// Protocol defining file storage operations (Firebase Storage)
protocol StorageRepositoryProtocol {
    /// Upload a profile image to storage
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: The user ID to associate with the image
    /// - Returns: The download URL of the uploaded image
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String

    /// Upload message image with optional progress tracking
    /// - Parameters:
    ///   - image: UIImage to compress and upload
    ///   - conversationId: Parent conversation ID (for storage path and security)
    ///   - messageId: Message ID (for storage path and progress tracking)
    ///   - progressHandler: Optional closure called with upload progress (0.0-1.0)
    /// - Returns: MessageAttachment with download URL and metadata
    func uploadMessageImage(
        _ image: UIImage,
        conversationId: String,
        messageId: String,
        progressHandler: ((Double) -> Void)?
    ) async throws -> MessageAttachment

    /// Upload message document (PDF) with optional progress tracking
    /// - Parameters:
    ///   - fileURL: Local file URL of the PDF document to upload
    ///   - conversationId: Parent conversation ID (for storage path and security)
    ///   - messageId: Message ID (for storage path and progress tracking)
    ///   - progressHandler: Optional closure called with upload progress (0.0-1.0)
    /// - Returns: MessageAttachment with download URL and metadata
    /// - Throws: StorageError if validation fails or upload fails
    func uploadMessageDocument(
        _ fileURL: URL,
        conversationId: String,
        messageId: String,
        progressHandler: ((Double) -> Void)?
    ) async throws -> MessageAttachment

    /// Cancel an in-progress upload
    /// - Parameter messageId: The message ID of the upload to cancel
    func cancelUpload(for messageId: String) async throws

    /// Delete a file from storage
    /// - Parameter path: The storage path to delete
    func deleteFile(at path: String) async throws
}


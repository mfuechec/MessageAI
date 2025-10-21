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
    
    /// Delete a file from storage
    /// - Parameter path: The storage path to delete
    func deleteFile(at path: String) async throws
}


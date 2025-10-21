//
//  FirebaseStorageRepository.swift
//  MessageAI
//
//  Firebase Storage implementation for file uploads
//

import Foundation
import FirebaseStorage
import UIKit

/// Firebase implementation of storage repository
class FirebaseStorageRepository: StorageRepositoryProtocol {
    private let storage = Storage.storage()
    
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("❌ Failed to convert image to data")
            throw StorageError.imageProcessingFailed
        }
        
        print("📤 Uploading profile image for user: \(userId), size: \(imageData.count) bytes")
        
        // Create storage reference
        let storageRef = storage.reference()
        let profileImageRef = storageRef.child("users/\(userId)/profile.jpg")
        
        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            // Upload the file
            let uploadMetadata = try await profileImageRef.putDataAsync(imageData, metadata: metadata)
            print("✅ Profile image uploaded for user: \(userId), path: \(uploadMetadata.path ?? "unknown")")
            
            // Get download URL
            let downloadURL = try await profileImageRef.downloadURL()
            print("✅ Download URL obtained: \(downloadURL.absoluteString)")
            
            return downloadURL.absoluteString
        } catch let error as NSError {
            print("❌ Profile image upload failed: \(error.localizedDescription)")
            print("   Error code: \(error.code), domain: \(error.domain)")
            
            // Map Firebase Storage errors to user-friendly messages
            if error.domain == "FIRStorageErrorDomain" {
                switch error.code {
                case -13021: // Unauthenticated
                    throw StorageError.unauthorized
                case -13020: // Unauthorized (permission denied)
                    throw StorageError.permissionDenied
                case -13010: // Object not found (shouldn't happen on upload, but just in case)
                    throw StorageError.storageNotConfigured
                case -13030: // Quota exceeded
                    throw StorageError.quotaExceeded
                case -13040: // Cancelled
                    throw StorageError.uploadCancelled
                default:
                    throw StorageError.uploadFailed(error.localizedDescription)
                }
            }
            
            throw StorageError.uploadFailed(error.localizedDescription)
        }
    }
    
    func deleteFile(at path: String) async throws {
        let storageRef = storage.reference()
        let fileRef = storageRef.child(path)
        
        do {
            try await fileRef.delete()
            print("✅ File deleted: \(path)")
        } catch {
            print("❌ File deletion failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
}


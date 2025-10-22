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
        print("🔵 [StorageRepo] uploadProfileImage called for user: \(userId)")
        
        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("❌ [StorageRepo] Failed to convert image to data")
            throw StorageError.imageProcessingFailed
        }
        
        print("📤 [StorageRepo] Uploading profile image for user: \(userId), size: \(imageData.count) bytes")
        
        // Create storage reference
        let storageRef = storage.reference()
        let storagePath = "profile-images/\(userId)/profile.jpg"
        let profileImageRef = storageRef.child(storagePath)
        
        print("🔵 [StorageRepo] Storage path: \(storagePath)")
        print("🔵 [StorageRepo] Full storage ref: \(profileImageRef.fullPath)")
        
        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            print("🔵 [StorageRepo] Calling putDataAsync...")
            // Upload the file
            let uploadMetadata = try await profileImageRef.putDataAsync(imageData, metadata: metadata)
            print("✅ [StorageRepo] Profile image uploaded for user: \(userId)")
            print("✅ [StorageRepo] Upload path: \(uploadMetadata.path ?? "unknown")")
            print("✅ [StorageRepo] Upload bucket: \(uploadMetadata.bucket ?? "unknown")")
            
            // Get download URL
            print("🔵 [StorageRepo] Getting download URL...")
            let downloadURL = try await profileImageRef.downloadURL()
            print("✅ [StorageRepo] Download URL obtained: \(downloadURL.absoluteString)")
            
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


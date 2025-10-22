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

    // Track active uploads for cancellation
    private var activeUploads: [String: StorageUploadTask] = [:]
    
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
    
    func uploadMessageImage(
        _ image: UIImage,
        conversationId: String,
        messageId: String,
        progressHandler: ((Double) -> Void)?
    ) async throws -> MessageAttachment {
        print("📤 [StorageRepo] Uploading image for message: \(messageId)")

        // Step 1: Compress image
        guard let compressedImage = ImageCompressor.compress(
            image: image,
            maxSizeBytes: 2 * 1024 * 1024  // 2MB
        ) else {
            throw StorageError.imageProcessingFailed
        }

        guard let imageData = compressedImage.jpegData(compressionQuality: 0.8) else {
            throw StorageError.imageProcessingFailed
        }

        let sizeBytes = Int64(imageData.count)
        print("✅ [StorageRepo] Image compressed: \(sizeBytes) bytes")

        // Step 2: Create storage reference
        let storagePath = "images/\(conversationId)/\(messageId)/image.jpg"
        let storageRef = storage.reference().child(storagePath)

        // Step 3: Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            // Step 4: Upload with progress tracking
            let uploadTask = storageRef.putData(imageData, metadata: metadata)
            activeUploads[messageId] = uploadTask

            // Observe progress
            uploadTask.observe(.progress) { snapshot in
                guard let progress = snapshot.progress else { return }
                let percentComplete = Double(progress.completedUnitCount)
                                    / Double(progress.totalUnitCount)

                Task { @MainActor in
                    progressHandler?(percentComplete)
                }
            }

            // Wait for completion
            let _ = try await uploadTask
            activeUploads.removeValue(forKey: messageId)

            print("✅ [StorageRepo] Upload complete: \(storagePath)")

            // Step 5: Get download URL
            let downloadURL = try await storageRef.downloadURL()

            // Step 6: Create MessageAttachment
            let attachment = MessageAttachment(
                id: UUID().uuidString,
                type: .image,
                url: downloadURL.absoluteString,
                thumbnailURL: nil,
                sizeBytes: sizeBytes
            )

            return attachment

        } catch let error as NSError {
            activeUploads.removeValue(forKey: messageId)
            print("❌ [StorageRepo] Upload failed: \(error.localizedDescription)")

            // Map Firebase Storage errors
            if error.domain == "FIRStorageErrorDomain" {
                switch error.code {
                case -13021: throw StorageError.unauthorized
                case -13020: throw StorageError.permissionDenied
                case -13030: throw StorageError.quotaExceeded
                case -13040: throw StorageError.uploadCancelled
                default: throw StorageError.uploadFailed(error.localizedDescription)
                }
            }

            throw StorageError.uploadFailed(error.localizedDescription)
        }
    }

    func cancelUpload(for messageId: String) async throws {
        guard let uploadTask = activeUploads[messageId] else {
            print("⚠️ [StorageRepo] No active upload found for message: \(messageId)")
            return
        }

        uploadTask.cancel()
        activeUploads.removeValue(forKey: messageId)
        print("✅ [StorageRepo] Upload cancelled for message: \(messageId)")
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


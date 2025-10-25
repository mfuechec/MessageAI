//
//  FirebaseStorageRepository.swift
//  MessageAI
//
//  Firebase Storage implementation for file uploads
//

import Foundation
import FirebaseStorage
import FirebaseAuth
import UIKit

/// Firebase implementation of storage repository
class FirebaseStorageRepository: StorageRepositoryProtocol {
    private let storage: Storage

    // Track active uploads for cancellation
    private var activeUploads: [String: StorageUploadTask] = [:]

    init(firebaseService: FirebaseService) {
        self.storage = firebaseService.storage
    }
    
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

        // DEBUG: Check auth state before upload
        if let currentUser = Auth.auth().currentUser {
            print("✅ [StorageRepo] User authenticated: \(currentUser.uid)")
        } else {
            print("❌ [StorageRepo] WARNING: No authenticated user!")
            throw StorageError.unauthorized
        }

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
            // Step 4: Upload with progress tracking using continuation for proper async/await
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

            // Wait for completion using continuation
            let uploadMetadata = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
                uploadTask.observe(.success) { snapshot in
                    guard let metadata = snapshot.metadata else {
                        continuation.resume(throwing: StorageError.uploadFailed("Upload succeeded but metadata is missing"))
                        return
                    }
                    continuation.resume(returning: metadata)
                }

                uploadTask.observe(.failure) { snapshot in
                    if let error = snapshot.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: StorageError.uploadFailed("Upload failed with unknown error"))
                    }
                }
            }

            activeUploads.removeValue(forKey: messageId)
            print("✅ [StorageRepo] Upload complete: \(storagePath)")
            print("✅ [StorageRepo] Upload metadata bucket: \(uploadMetadata.bucket ?? "unknown")")
            print("✅ [StorageRepo] Upload metadata path: \(uploadMetadata.path ?? "unknown")")

            // Step 5: Get download URL
            let downloadURL = try await storageRef.downloadURL()

            // Step 6: Create MessageAttachment
            let attachment = MessageAttachment(
                id: UUID().uuidString,
                type: .image,
                url: downloadURL.absoluteString,
                thumbnailURL: nil,
                sizeBytes: sizeBytes,
                fileName: nil,  // Images don't need file name
                aiSummary: nil  // No AI summary for images
            )

            return attachment

        } catch let error as NSError {
            activeUploads.removeValue(forKey: messageId)
            print("❌ [StorageRepo] Upload failed: \(error.localizedDescription)")
            print("❌ [StorageRepo] Error domain: \(error.domain), code: \(error.code)")

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

    func uploadMessageDocument(
        _ fileURL: URL,
        conversationId: String,
        messageId: String,
        progressHandler: ((Double) -> Void)?
    ) async throws -> MessageAttachment {
        let startTime = Date()
        print("📤 [StorageRepo] Uploading document for message: \(messageId)")

        // Step 1: Validate document using DocumentValidator
        let (fileName, sizeBytes) = try DocumentValidator.validate(fileURL: fileURL)
        print("✅ [StorageRepo] Document validated: \(fileName), \(sizeBytes) bytes")

        // Step 2: Read file data
        guard let documentData = try? Data(contentsOf: fileURL) else {
            throw StorageError.imageProcessingFailed  // Reuse existing error (rename generic later if needed)
        }

        // Step 3: Create storage reference
        let storagePath = "documents/\(conversationId)/\(messageId)/document.pdf"
        let storageRef = storage.reference().child(storagePath)

        // Step 4: Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "application/pdf"
        metadata.customMetadata = ["fileName": fileName]

        do {
            // Step 5: Upload with progress tracking using continuation for proper async/await
            let uploadTask = storageRef.putData(documentData, metadata: metadata)
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

            // Wait for completion using continuation
            let uploadMetadata = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
                uploadTask.observe(.success) { snapshot in
                    guard let metadata = snapshot.metadata else {
                        continuation.resume(throwing: StorageError.uploadFailed("Upload succeeded but metadata is missing"))
                        return
                    }
                    continuation.resume(returning: metadata)
                }

                uploadTask.observe(.failure) { snapshot in
                    if let error = snapshot.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: StorageError.uploadFailed("Upload failed with unknown error"))
                    }
                }
            }

            activeUploads.removeValue(forKey: messageId)

            let duration = Date().timeIntervalSince(startTime)
            print("✅ [StorageRepo] Document upload complete: \(storagePath), duration: \(String(format: "%.2f", duration))s")
            print("✅ [StorageRepo] Upload metadata bucket: \(uploadMetadata.bucket ?? "unknown")")
            print("✅ [StorageRepo] Upload metadata path: \(uploadMetadata.path ?? "unknown")")

            // Step 6: Get download URL
            let downloadURL = try await storageRef.downloadURL()

            // Step 7: Create MessageAttachment (AI summary added later by ChatViewModel)
            let attachment = MessageAttachment(
                id: UUID().uuidString,
                type: .file,
                url: downloadURL.absoluteString,
                thumbnailURL: nil,
                sizeBytes: sizeBytes,
                fileName: fileName,
                aiSummary: nil  // Will be populated by ChatViewModel after upload
            )

            return attachment

        } catch let error as NSError {
            activeUploads.removeValue(forKey: messageId)
            print("❌ [StorageRepo] Document upload failed: \(error.localizedDescription)")
            print("❌ [StorageRepo] Error domain: \(error.domain), code: \(error.code)")

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


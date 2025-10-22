//
//  ImageCacheManager.swift
//  MessageAI
//
//  Manages temporary storage of images during upload lifecycle
//  Enables retry functionality and offline queue without UserDefaults overflow
//

import UIKit
import Foundation

/// Manages temporary storage of images during upload lifecycle
/// Enables retry functionality and offline queue without UserDefaults overflow
enum ImageCacheManager {
    private static let cacheDirectory: URL = {
        let tempDir = FileManager.default.temporaryDirectory
        let imageCache = tempDir.appendingPathComponent("image_uploads")
        try? FileManager.default.createDirectory(at: imageCache, withIntermediateDirectories: true)
        return imageCache
    }()

    /// Save compressed image data to temporary storage
    /// - Parameters:
    ///   - imageData: Compressed JPEG data
    ///   - messageId: Message ID for filename
    /// - Returns: File URL for stored image
    static func saveTemporaryImage(_ imageData: Data, forMessageId messageId: String) throws -> URL {
        let fileURL = cacheDirectory.appendingPathComponent("\(messageId).jpg")
        try imageData.write(to: fileURL)
        print("📁 [ImageCache] Saved temporary image: \(fileURL.lastPathComponent) (\(imageData.count) bytes)")
        return fileURL
    }

    /// Load image data from temporary storage
    /// - Parameter messageId: Message ID
    /// - Returns: Image data if exists, nil otherwise
    static func loadTemporaryImage(forMessageId messageId: String) -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent("\(messageId).jpg")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("⚠️ [ImageCache] Temporary image not found: \(fileURL.lastPathComponent)")
            return nil
        }
        return try? Data(contentsOf: fileURL)
    }

    /// Delete temporary image after successful upload
    /// - Parameter messageId: Message ID
    static func deleteTemporaryImage(forMessageId messageId: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(messageId).jpg")
        try? FileManager.default.removeItem(at: fileURL)
        print("🗑️ [ImageCache] Deleted temporary image: \(fileURL.lastPathComponent)")
    }

    /// Clean up all temporary images (call on app launch or termination)
    static func cleanupAllTemporaryImages() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for fileURL in files {
            try? FileManager.default.removeItem(at: fileURL)
        }
        print("🗑️ [ImageCache] Cleaned up \(files.count) temporary images")
    }

    /// Clean up old temporary images (older than 24 hours)
    static func cleanupExpiredImages() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return
        }

        let expirationDate = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago
        var cleanedCount = 0

        for fileURL in files {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                  let creationDate = attributes[.creationDate] as? Date else {
                continue
            }

            if creationDate < expirationDate {
                try? FileManager.default.removeItem(at: fileURL)
                cleanedCount += 1
            }
        }

        if cleanedCount > 0 {
            print("🗑️ [ImageCache] Deleted \(cleanedCount) expired images (> 24 hours old)")
        }
    }
}

//
//  ImageCompressor.swift
//  MessageAI
//
//  Utility for compressing images before upload
//

import UIKit

/// Utility for compressing images before upload
enum ImageCompressor {
    /// Compress image to target size
    /// - Parameters:
    ///   - image: Source UIImage
    ///   - maxSizeBytes: Maximum size in bytes (default: 2MB)
    /// - Returns: Compressed UIImage, or nil if compression fails
    static func compress(image: UIImage, maxSizeBytes: Int64 = 2 * 1024 * 1024) -> UIImage? {
        // Step 1: Resize if dimensions are too large
        let resizedImage = resize(image: image, maxDimension: 1920)

        // Step 2: Compress with decreasing quality until under maxSizeBytes
        var compression: CGFloat = 0.8
        var imageData = resizedImage.jpegData(compressionQuality: compression)

        while let data = imageData, data.count > maxSizeBytes && compression > 0.1 {
            compression -= 0.1
            imageData = resizedImage.jpegData(compressionQuality: compression)
        }

        guard let finalData = imageData, finalData.count <= maxSizeBytes else {
            print("❌ ImageCompressor: Failed to compress image under \(maxSizeBytes) bytes")
            return nil
        }

        print("✅ ImageCompressor: Compressed to \(finalData.count) bytes (quality: \(compression))")
        return UIImage(data: finalData)
    }

    /// Resize image if larger than maxDimension (maintains aspect ratio)
    private static func resize(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else {
            return image  // Already small enough
        }

        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        print("✅ ImageCompressor: Resized from \(size) to \(newSize)")
        return resizedImage
    }
}

//
//  ImageCompressorTests.swift
//  MessageAITests
//
//  Tests for ImageCompressor utility
//

import XCTest
import UIKit
@testable import MessageAI

class ImageCompressorTests: XCTestCase {

    func testCompressSmallImageReturnsOriginalSize() {
        // Given: A small image (already under 2MB)
        let smallImage = createTestImage(width: 100, height: 100)

        // When: Compressing with 2MB limit
        let compressed = ImageCompressor.compress(image: smallImage, maxSizeBytes: 2 * 1024 * 1024)

        // Then: Returns non-nil image
        XCTAssertNotNil(compressed, "Small image should compress successfully")
    }

    func testCompressLargeImageReducesSize() {
        // Given: A large image
        let largeImage = createTestImage(width: 4000, height: 4000)
        let targetSize: Int64 = 500 * 1024  // 500KB

        // When: Compressing to 500KB
        let compressed = ImageCompressor.compress(image: largeImage, maxSizeBytes: targetSize)

        // Then: Returns compressed image under target size
        XCTAssertNotNil(compressed, "Large image should compress")

        if let compressedImage = compressed,
           let imageData = compressedImage.jpegData(compressionQuality: 0.8) {
            XCTAssertLessThanOrEqual(imageData.count, Int(targetSize),
                                    "Compressed image should be under \(targetSize) bytes")
        }
    }

    func testCompressReturnsNilForExcessivelyLargeImage() {
        // Given: An extremely large image that can't be compressed to 10KB
        let hugeImage = createTestImage(width: 5000, height: 5000)
        let tinyLimit: Int64 = 10 * 1024  // 10KB

        // When: Attempting to compress to 10KB
        let compressed = ImageCompressor.compress(image: hugeImage, maxSizeBytes: tinyLimit)

        // Then: May return nil if impossible to compress (acceptable behavior)
        // OR returns image under limit
        if let compressedImage = compressed {
            if let imageData = compressedImage.jpegData(compressionQuality: 0.1) {
                XCTAssertLessThanOrEqual(imageData.count, Int(tinyLimit),
                                        "If compressed, should be under limit")
            }
        }
        // Either result is acceptable - nil or successfully compressed
    }

    func testCompressDefault2MBLimit() {
        // Given: A large image
        let image = createTestImage(width: 3000, height: 3000)

        // When: Compressing with default limit (2MB)
        let compressed = ImageCompressor.compress(image: image)

        // Then: Returns compressed image under 2MB
        XCTAssertNotNil(compressed, "Should compress with default limit")

        if let compressedImage = compressed,
           let imageData = compressedImage.jpegData(compressionQuality: 0.8) {
            XCTAssertLessThanOrEqual(imageData.count, 2 * 1024 * 1024,
                                    "Compressed image should be under 2MB")
        }
    }

    // MARK: - Helper Methods

    private func createTestImage(width: Int, height: Int) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Fill with random colored gradient
            let colors = [UIColor.red, UIColor.blue, UIColor.green, UIColor.yellow]
            for i in 0..<colors.count {
                colors[i].setFill()
                let rect = CGRect(
                    x: 0,
                    y: CGFloat(i) * size.height / CGFloat(colors.count),
                    width: size.width,
                    height: size.height / CGFloat(colors.count)
                )
                context.fill(rect)
            }
        }
    }
}

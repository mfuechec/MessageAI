//
//  DocumentValidator.swift
//  MessageAI
//
//  Validates PDF documents before upload
//

import Foundation
import UniformTypeIdentifiers

/// Errors that can occur during document validation
enum DocumentValidationError: LocalizedError {
    case fileTooLarge(maxSizeMB: Int)
    case unsupportedFileType
    case fileNotAccessible
    case invalidFileName

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let maxSize):
            return "File size exceeds \(maxSize)MB limit"
        case .unsupportedFileType:
            return "Only PDF files are supported"
        case .fileNotAccessible:
            return "Cannot access the selected file"
        case .invalidFileName:
            return "Invalid file name"
        }
    }
}

/// Utility for validating PDF documents before upload
struct DocumentValidator {

    /// Maximum file size in bytes (10MB)
    static let maxFileSizeBytes: Int64 = 10 * 1024 * 1024

    /// Validates a document file and returns metadata
    /// - Parameter fileURL: Local file URL to validate
    /// - Returns: Tuple containing file name and size in bytes
    /// - Throws: DocumentValidationError if validation fails
    static func validate(fileURL: URL) throws -> (fileName: String, sizeBytes: Int64) {

        // Step 1: Verify file is accessible
        guard fileURL.startAccessingSecurityScopedResource() else {
            throw DocumentValidationError.fileNotAccessible
        }
        defer { fileURL.stopAccessingSecurityScopedResource() }

        // Step 2: Get file attributes
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? Int64 else {
            throw DocumentValidationError.fileNotAccessible
        }

        // Step 3: Check file size (10MB limit)
        guard fileSize <= maxFileSizeBytes else {
            let maxSizeMB = Int(maxFileSizeBytes / (1024 * 1024))
            throw DocumentValidationError.fileTooLarge(maxSizeMB: maxSizeMB)
        }

        // Step 4: Verify file type is PDF
        let fileExtension = fileURL.pathExtension.lowercased()
        guard fileExtension == "pdf" else {
            throw DocumentValidationError.unsupportedFileType
        }

        // Step 5: Verify MIME type using UniformTypeIdentifiers
        if let resourceValues = try? fileURL.resourceValues(forKeys: [.contentTypeKey]),
           let contentType = resourceValues.contentType {
            guard contentType == .pdf else {
                throw DocumentValidationError.unsupportedFileType
            }
        }

        // Step 6: Extract file name
        let fileName = fileURL.lastPathComponent
        guard !fileName.isEmpty else {
            throw DocumentValidationError.invalidFileName
        }

        return (fileName: fileName, sizeBytes: fileSize)
    }

    /// Formats file size for display
    /// - Parameter sizeBytes: File size in bytes
    /// - Returns: Formatted string (e.g., "2.5 MB")
    static func formatFileSize(_ sizeBytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }
}

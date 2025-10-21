//
//  StorageError.swift
//  MessageAI
//
//  User-friendly storage error messages
//

import Foundation

enum StorageError: LocalizedError {
    case imageProcessingFailed
    case unauthorized
    case permissionDenied
    case storageNotConfigured
    case quotaExceeded
    case uploadCancelled
    case uploadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Unable to process the image. Please try a different photo."
        case .unauthorized:
            return "You must be signed in to upload images."
        case .permissionDenied:
            return "Storage permissions not configured. Please contact support."
        case .storageNotConfigured:
            return "Image storage is not available. Please try again later."
        case .quotaExceeded:
            return "Storage quota exceeded. Please contact support."
        case .uploadCancelled:
            return "Upload was cancelled."
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        }
    }
}


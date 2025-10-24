import Foundation

/// Error types for repository operations
enum RepositoryError: LocalizedError {
    case userNotFound(String)
    case conversationNotFound(String)
    case messageNotFound(String)
    case notFound
    case unauthorized
    case invalidInput
    case networkError(Error)
    case encodingError(Error)
    case decodingError(Error)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound(let id):
            return "User not found: \(id)"
        case .conversationNotFound(let id):
            return "Conversation not found: \(id)"
        case .messageNotFound(let id):
            return "Message not found: \(id)"
        case .notFound:
            return "Resource not found"
        case .unauthorized:
            return "Unauthorized access"
        case .invalidInput:
            return "Invalid input parameters"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}


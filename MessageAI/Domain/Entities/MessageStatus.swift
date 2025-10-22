import Foundation

/// Message delivery and read status with state transition validation
enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
    case failed
    case queued  // For offline uploads waiting for network

    /// Sort order for status progression (0 = earliest, 3 = final)
    var sortOrder: Int {
        switch self {
        case .sending: return 0
        case .failed: return 0
        case .queued: return 0
        case .sent: return 1
        case .delivered: return 2
        case .read: return 3
        }
    }
    
    /// Validates if transition to new status is allowed
    /// - Parameter newStatus: The target status to transition to
    /// - Returns: True if transition is valid (forward progression only)
    func canTransitionTo(_ newStatus: MessageStatus) -> Bool {
        return newStatus.sortOrder >= self.sortOrder
    }
}


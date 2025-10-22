import Foundation

/// Network retry policy with exponential backoff for handling transient failures
struct NetworkRetryPolicy {
    static let maxRetries = 3
    static let timeoutSeconds: TimeInterval = 10.0

    /// Calculate exponential backoff delay: 2s, 4s, 8s (2^attempt)
    static func delay(for attempt: Int) -> TimeInterval {
        return pow(2.0, Double(attempt))
    }

    /// Retry async operation with exponential backoff and timeout
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts (default: 3)
    ///   - timeoutPerAttempt: Timeout for each attempt (default: 10s)
    ///   - delayMultiplier: Multiplier for exponential delay (default: 1.0, use 0.001 for fast tests)
    ///   - operation: The async operation to retry
    /// - Returns: Result of the operation
    /// - Throws: Last error if all retries fail
    static func retry<T>(
        maxAttempts: Int = maxRetries,
        timeoutPerAttempt: TimeInterval = timeoutSeconds,
        delayMultiplier: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var attempt = 0
        var lastError: Error?

        while attempt < maxAttempts {
            do {
                // Execute operation with timeout
                return try await withTimeout(seconds: timeoutPerAttempt) {
                    try await operation()
                }
            } catch {
                lastError = error
                attempt += 1

                if attempt >= maxAttempts {
                    throw error
                }

                let delaySeconds = delay(for: attempt) * delayMultiplier
                print("⚠️ NetworkRetryPolicy: Retry attempt \(attempt)/\(maxAttempts) after \(delaySeconds)s - Error: \(error.localizedDescription)")

                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
        }

        // Should never reach here, but satisfy compiler
        throw lastError ?? NetworkError.retryFailed
    }

    /// Execute operation with timeout
    /// - Parameters:
    ///   - seconds: Timeout in seconds
    ///   - operation: Operation to execute
    /// - Returns: Result of operation
    /// - Throws: TimeoutError if operation exceeds timeout, or operation error
    static func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NetworkError.timeout
            }

            // Add operation task
            group.addTask {
                try await operation()
            }

            // Wait for first task to complete
            guard let result = try await group.next() else {
                throw NetworkError.timeout
            }

            // Cancel remaining tasks
            group.cancelAll()

            return result
        }
    }
}

/// Network-related errors
enum NetworkError: LocalizedError {
    case timeout
    case retryFailed

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Operation timed out. Please check your connection and try again."
        case .retryFailed:
            return "Operation failed after multiple retries."
        }
    }
}

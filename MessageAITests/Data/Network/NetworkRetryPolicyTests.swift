import XCTest
@testable import MessageAI

final class NetworkRetryPolicyTests: XCTestCase {

    // MARK: - Test Exponential Backoff Delays

    func testExponentialBackoffDelays() {
        // Test that delays follow exponential pattern: 1s, 2s, 4s

        let delay1 = NetworkRetryPolicy.delay(for: 1)
        let delay2 = NetworkRetryPolicy.delay(for: 2)
        let delay3 = NetworkRetryPolicy.delay(for: 3)

        XCTAssertEqual(delay1, 2.0, accuracy: 0.001, "First retry should wait 2^1 = 2s")
        XCTAssertEqual(delay2, 4.0, accuracy: 0.001, "Second retry should wait 2^2 = 4s")
        XCTAssertEqual(delay3, 8.0, accuracy: 0.001, "Third retry should wait 2^3 = 8s")
    }

    // MARK: - Test Retry Success After Failure

    func testRetrySucceedsAfterFailure() async throws {
        // Test that retry succeeds on second attempt

        var attemptCount = 0

        let result = try await NetworkRetryPolicy.retry(delayMultiplier: 0.001) {
            attemptCount += 1

            if attemptCount == 1 {
                // First attempt fails
                throw TestError.transientFailure
            }

            // Second attempt succeeds
            return "Success"
        }

        XCTAssertEqual(result, "Success", "Should return success result")
        XCTAssertEqual(attemptCount, 2, "Should have attempted twice")
    }

    // MARK: - Test Retry Throws After Max Attempts

    func testRetryThrowsAfterMaxAttempts() async {
        // Test that retry throws error after max attempts

        var attemptCount = 0

        do {
            _ = try await NetworkRetryPolicy.retry(maxAttempts: 3, timeoutPerAttempt: 0.1, delayMultiplier: 0.001) {
                attemptCount += 1
                throw TestError.permanentFailure
            }

            XCTFail("Should have thrown error after max attempts")
        } catch {
            XCTAssertEqual(attemptCount, 3, "Should have attempted max times")
            XCTAssertTrue(error is TestError, "Should throw original error")
        }
    }

    // MARK: - Test First Attempt Success

    func testRetrySucceedsOnFirstAttempt() async throws {
        // Test that retry succeeds on first attempt without retrying

        var attemptCount = 0

        let result = try await NetworkRetryPolicy.retry {
            attemptCount += 1
            return "Immediate Success"
        }

        XCTAssertEqual(result, "Immediate Success", "Should return success result")
        XCTAssertEqual(attemptCount, 1, "Should only attempt once")
    }

    // MARK: - Test Timeout Enforced

    func testTimeoutEnforced() async {
        // Test that operation times out after timeout period

        let start = Date()

        do {
            _ = try await NetworkRetryPolicy.withTimeout(seconds: 1.0) {
                // Operation takes longer than timeout
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                return "Should not complete"
            }

            XCTFail("Should have thrown timeout error")
        } catch {
            let duration = Date().timeIntervalSince(start)

            // Should timeout around 1 second (not wait 3 seconds)
            XCTAssertLessThan(duration, 2.0, "Should timeout within ~1 second, not wait full 3s")
            XCTAssertTrue(error is NetworkError, "Should throw NetworkError")

            if let networkError = error as? NetworkError {
                XCTAssertEqual(networkError, NetworkError.timeout, "Should be timeout error")
            }
        }
    }

    // MARK: - Test Timeout Success

    func testTimeoutSuccessBeforeTimeout() async throws {
        // Test that operation succeeds if completed before timeout

        let result = try await NetworkRetryPolicy.withTimeout(seconds: 2.0) {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            return "Completed in time"
        }

        XCTAssertEqual(result, "Completed in time", "Should complete successfully")
    }

    // MARK: - Test Retry with Timeout

    func testRetryWithTimeoutOnEachAttempt() async {
        // Test that timeout applies to each retry attempt

        var attemptCount = 0
        let start = Date()

        do {
            _ = try await NetworkRetryPolicy.retry(maxAttempts: 2, timeoutPerAttempt: 0.5, delayMultiplier: 0.001) {
                attemptCount += 1
                // Each attempt takes longer than timeout
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                return "Should not complete"
            }

            XCTFail("Should have thrown timeout error")
        } catch {
            let duration = Date().timeIntervalSince(start)

            // Should timeout on first attempt (~0.5s), then retry and timeout again (~0.5s)
            // Plus exponential backoff delay (~0.002s) = ~1s total
            XCTAssertLessThan(duration, 2.0, "Should timeout attempts quickly")
            XCTAssertEqual(attemptCount, 2, "Should have attempted twice before final failure")
        }
    }

    // MARK: - Test Helper Errors

    enum TestError: Error {
        case transientFailure
        case permanentFailure
    }
}

//
//  MockNetworkMonitor.swift
//  MessageAITests
//
//  Created by Dev Agent (James) on 10/21/25.
//

import Foundation
import Combine
@testable import MessageAI

/// Mock implementation of NetworkMonitor for unit testing
///
/// Provides controllable network state simulation without requiring
/// actual network changes or NWPathMonitor.
///
/// Usage in tests:
/// ```swift
/// let mockMonitor = MockNetworkMonitor()
/// let viewModel = ChatViewModel(..., networkMonitor: mockMonitor)
///
/// // Simulate going offline
/// mockMonitor.simulateOffline()
///
/// // Verify offline state
/// XCTAssertTrue(viewModel.isOffline)
/// ```
class MockNetworkMonitor: NetworkMonitorProtocol {

    // MARK: - Published Properties

    /// Simulated network connection state
    @Published var isConnected: Bool = true

    /// Publisher for network connectivity changes
    var isConnectedPublisher: Published<Bool>.Publisher { $isConnected }

    /// Simulated Firestore connection state
    @Published var isFirestoreConnected: Bool = true

    /// Publisher for Firestore connectivity changes
    var isFirestoreConnectedPublisher: Published<Bool>.Publisher { $isFirestoreConnected }

    /// Effective connectivity state (source of truth)
    /// Trust Firestore as the primary authority
    var isEffectivelyConnected: Bool {
        return isFirestoreConnected
    }

    /// Publisher for effective connectivity changes (source of truth)
    /// Emits when EITHER changes but always returns Firestore state
    var isEffectivelyConnectedPublisher: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest($isConnected, $isFirestoreConnected)
            .map { _, isFirestoreConnected in
                return isFirestoreConnected
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Public Methods

    /// Simulates network disconnection (airplane mode, WiFi off, etc.)
    func simulateOffline() {
        isConnected = false
        isFirestoreConnected = false
    }

    /// Simulates network reconnection
    func simulateOnline() {
        isConnected = true
        isFirestoreConnected = true
    }

    /// Simulates Firestore-specific disconnection (while OS network is still up)
    func simulateFirestoreDisconnect() {
        isFirestoreConnected = false
    }

    /// Simulates Firestore reconnection
    func simulateFirestoreReconnect() {
        isFirestoreConnected = true
    }

    /// Resets to default online state
    func reset() {
        isConnected = true
        isFirestoreConnected = true
    }

    /// Simulate connectivity change to trigger observers (Story 2.9)
    func simulateConnectivityChange() {
        // Toggle to trigger publisher
        let current = isConnected
        isConnected = !current
        isConnected = current
    }

    /// Retry Firestore monitoring (no-op for mock)
    func retryFirestoreMonitoring() {
        // No-op for mock - just here for protocol conformance
    }
}


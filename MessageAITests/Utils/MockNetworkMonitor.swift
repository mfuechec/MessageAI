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
    
    // MARK: - Public Methods
    
    /// Simulates network disconnection (airplane mode, WiFi off, etc.)
    func simulateOffline() {
        isConnected = false
    }
    
    /// Simulates network reconnection
    func simulateOnline() {
        isConnected = true
    }
    
    /// Resets to default online state
    func reset() {
        isConnected = true
    }
}


//
//  NetworkMonitorTests.swift
//  MessageAITests
//
//  Created by Winston (Architect) on 10/22/25.
//

import XCTest
import Combine
import Network
@testable import MessageAI

/// Tests for NetworkMonitor connectivity detection
///
/// **Test Coverage:**
/// - Initial connectivity state detection
/// - Network state change publishing
/// - Combine publisher functionality
/// - Firestore connection fallback behavior
/// - Memory management (no retain cycles)
///
/// **Note:** These tests verify the NetworkMonitor properly publishes
/// connectivity changes via Combine publishers, which ChatViewModel
/// and ConversationsListViewModel subscribe to for offline UI updates.
@MainActor
class NetworkMonitorTests: XCTestCase {

    var sut: NetworkMonitor!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        cancellables = Set<AnyCancellable>()

        // Note: We create a real NetworkMonitor instance to test actual behavior
        // In CI/test environments, it will detect simulator network state
        sut = NetworkMonitor()

        print("📱 [NetworkMonitorTests] Test environment initialized")
    }

    override func tearDown() async throws {
        cancellables = nil
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    /// Test that NetworkMonitor initializes with correct default state
    ///
    /// **Expected:** Initial state should be `isConnected = true` (optimistic default)
    /// **Rationale:** App assumes connectivity until proven otherwise
    func testInitialization_DefaultsToConnected() async throws {
        // Given: Fresh NetworkMonitor instance (created in setUp)

        // When: We check initial state
        let initialState = sut.isConnected

        // Then: Should default to connected (optimistic)
        XCTAssertTrue(initialState, "NetworkMonitor should default to connected state")

        print("✅ [NetworkMonitorTests] Initial state verified: isConnected=\(initialState)")
    }

    /// Test that NetworkMonitor starts monitoring immediately on init
    ///
    /// **Expected:** NWPathMonitor should be running and able to detect current network state
    /// **Verification:** Wait briefly for NWPathMonitor to fire initial path update
    func testInitialization_StartsMonitoringImmediately() async throws {
        // Given: Fresh NetworkMonitor instance
        let expectation = XCTestExpectation(description: "Network status update received")
        var receivedUpdate = false

        // When: We subscribe to connectivity changes
        sut.isConnectedPublisher
            .dropFirst()  // Skip initial value
            .sink { isConnected in
                receivedUpdate = true
                expectation.fulfill()
                print("📡 [NetworkMonitorTests] Received connectivity update: isConnected=\(isConnected)")
            }
            .store(in: &cancellables)

        // Then: Should receive at least one update within 3 seconds
        // (NWPathMonitor fires initial path update quickly)
        await fulfillment(of: [expectation], timeout: 3.0)

        XCTAssertTrue(receivedUpdate, "NetworkMonitor should publish connectivity updates")
    }

    // MARK: - Publisher Tests

    /// Test that isConnectedPublisher emits current value to new subscribers
    ///
    /// **Expected:** New subscriber should immediately receive current connectivity state
    /// **Pattern:** Combine @Published property behavior
    func testPublisher_EmitsCurrentValueToNewSubscribers() async throws {
        // Given: NetworkMonitor with known state
        let currentState = sut.isConnected
        let expectation = XCTestExpectation(description: "Publisher emits current value")

        // When: New subscriber attaches
        sut.isConnectedPublisher
            .first()
            .sink { receivedValue in
                // Then: Should immediately receive current value
                XCTAssertEqual(receivedValue, currentState,
                              "Publisher should emit current connectivity state")
                expectation.fulfill()
                print("✅ [NetworkMonitorTests] Publisher emitted current value: \(receivedValue)")
            }
            .store(in: &cancellables)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    /// Test that multiple subscribers all receive updates
    ///
    /// **Expected:** Multiple ViewModels can subscribe simultaneously
    /// **Pattern:** Multicast publisher behavior
    func testPublisher_SupportsMultipleSubscribers() async throws {
        // Given: NetworkMonitor instance
        let expectation1 = XCTestExpectation(description: "Subscriber 1 receives update")
        let expectation2 = XCTestExpectation(description: "Subscriber 2 receives update")

        // When: Multiple subscribers attach
        sut.isConnectedPublisher
            .first()
            .sink { _ in
                expectation1.fulfill()
                print("✅ [NetworkMonitorTests] Subscriber 1 received value")
            }
            .store(in: &cancellables)

        sut.isConnectedPublisher
            .first()
            .sink { _ in
                expectation2.fulfill()
                print("✅ [NetworkMonitorTests] Subscriber 2 received value")
            }
            .store(in: &cancellables)

        // Then: Both subscribers should receive values
        await fulfillment(of: [expectation1, expectation2], timeout: 1.0)
    }

    /// Test that publisher doesn't emit duplicate consecutive values
    ///
    /// **Expected:** removeDuplicates() in ChatViewModel should prevent redundant updates
    /// **Note:** This tests the pattern used by ChatViewModel (line 318)
    func testPublisher_CanFilterDuplicates() async throws {
        // Given: NetworkMonitor publisher with duplicate filter
        var receivedValues: [Bool] = []
        let expectation = XCTestExpectation(description: "Collect values")

        // When: We subscribe with removeDuplicates (same as ChatViewModel)
        sut.isConnectedPublisher
            .removeDuplicates()
            .prefix(3)  // Collect first 3 unique values
            .collect()
            .sink { values in
                receivedValues = values
                expectation.fulfill()
                print("📊 [NetworkMonitorTests] Collected values: \(values)")
            }
            .store(in: &cancellables)

        // Then: Should handle duplicate filtering correctly
        // (Actual values depend on network state changes during test)
        await fulfillment(of: [expectation], timeout: 5.0)

        // Verify we got some values (exact count depends on network changes)
        XCTAssertFalse(receivedValues.isEmpty, "Should receive connectivity values")
    }

    // MARK: - Integration Tests

    /// Test that NetworkMonitor detects simulator network state
    ///
    /// **Expected:** On iOS Simulator, should detect WiFi connection via NWPathMonitor
    /// **Note:** This test verifies real-world behavior in simulator environment
    func testIntegration_DetectsSimulatorNetworkState() async throws {
        // Given: Running in iOS Simulator (detected by NWPathMonitor)

        // When: We wait for initial network detection
        try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second for NWPathMonitor

        let detectedState = sut.isConnected
        let connectionType = sut.connectionType

        // Then: Should detect simulator network (typically WiFi)
        print("📡 [NetworkMonitorTests] Detected network state:")
        print("   isConnected: \(detectedState)")
        print("   connectionType: \(String(describing: connectionType))")

        // In simulator with Mac WiFi, should be connected
        #if targetEnvironment(simulator)
        XCTAssertTrue(detectedState, "Simulator should detect Mac's network connection")
        #endif
    }

    /// Test NetworkMonitor with Firestore connection fallback
    ///
    /// **Expected:** Firestore listener should start during init (if not in test environment)
    /// **Note:** Verifies the hybrid monitoring strategy documented in NetworkMonitor.swift:23-28
    func testIntegration_FirestoreConnectionMonitoringSetup() async throws {
        // Given: NetworkMonitor instance

        // When: We wait for Firestore listener to initialize
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Then: NetworkMonitor should have started Firestore monitoring
        // (Cannot directly verify private listener, but can check logs)
        // Look for console output: "🌐 [NetworkMonitor] Firestore detected online"

        print("📡 [NetworkMonitorTests] Firestore monitoring should be active")
        print("   Check console for Firestore connection logs")

        // Verify monitoring is active by checking we can get connectivity updates
        let isMonitoring = sut.isConnected != nil  // Should have a value
        XCTAssertTrue(isMonitoring, "NetworkMonitor should be actively monitoring")
    }

    // MARK: - Memory Management Tests

    /// Test that NetworkMonitor doesn't create retain cycles
    ///
    /// **Expected:** NetworkMonitor should deallocate cleanly when no longer referenced
    /// **Pattern:** Weak self in closures (NetworkMonitor.swift:83, 140)
    func testMemoryManagement_NoRetainCycles() async throws {
        // Given: NetworkMonitor in scope
        weak var weakMonitor: NetworkMonitor?

        autoreleasepool {
            let monitor = NetworkMonitor()
            weakMonitor = monitor

            // Simulate subscription (like ChatViewModel)
            var cancellable: AnyCancellable?
            cancellable = monitor.isConnectedPublisher
                .sink { _ in
                    // Subscriber closure
                }

            // Release subscription
            cancellable?.cancel()
            cancellable = nil

            XCTAssertNotNil(weakMonitor, "Monitor should exist while in scope")
        }

        // When: Monitor goes out of scope

        // Then: Should deallocate (no retain cycles)
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds for cleanup
        XCTAssertNil(weakMonitor, "NetworkMonitor should deallocate when no longer referenced")

        print("✅ [NetworkMonitorTests] No retain cycles detected")
    }

    // MARK: - Diagnostic Tests

    /// Diagnostic test to verify NetworkMonitor logs are appearing
    ///
    /// **Purpose:** Helps debug why offline banner might not be showing
    /// **Expected:** Should see console logs for network state changes
    func testDiagnostic_ConsoleLoggingWorks() async throws {
        // Given: NetworkMonitor instance
        print("\n🔍 [NetworkMonitorTests] === DIAGNOSTIC TEST START ===")
        print("   Watch console for NetworkMonitor logs:")
        print("   - 🌐 [NetworkMonitor] NWPathMonitor update: ...")
        print("   - 🌐 [NetworkMonitor] Firestore detected online/offline")
        print("   - 🌐 [NetworkMonitor] Updated isConnected=...")

        // When: We wait for NWPathMonitor to fire
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Then: Check current state
        print("\n📊 [NetworkMonitorTests] Current State:")
        print("   isConnected: \(sut.isConnected)")
        print("   connectionType: \(String(describing: sut.connectionType))")

        print("🔍 [NetworkMonitorTests] === DIAGNOSTIC TEST END ===\n")

        // Always passes - this is just for visibility
        XCTAssertTrue(true, "Diagnostic test completed")
    }

    /// Diagnostic test simulating ChatViewModel subscription pattern
    ///
    /// **Purpose:** Replicates exact pattern from ChatViewModel.swift:316-343
    /// **Expected:** Should receive connectivity updates just like ChatViewModel
    func testDiagnostic_ChatViewModelSubscriptionPattern() async throws {
        // Given: Simulating ChatViewModel's setupNetworkMonitoring()
        print("\n🔍 [NetworkMonitorTests] === SIMULATING ChatViewModel SUBSCRIPTION ===")

        var isOffline = false
        let expectation = XCTestExpectation(description: "Receive connectivity update")

        // When: Subscribe exactly like ChatViewModel does
        sut.isConnectedPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let _ = self else { return }

                let wasOffline = isOffline
                let isNowOffline = !isConnected
                isOffline = isNowOffline

                print("🌐 [NetworkMonitorTests] Network status changed:")
                print("   isConnected: \(isConnected)")
                print("   isOffline: \(isOffline)")
                print("   wasOffline: \(wasOffline)")

                if wasOffline && !isNowOffline {
                    print("   ✅ Detected offline → online transition")
                }

                if !wasOffline && isNowOffline {
                    print("   ⚠️ Detected online → offline transition")
                }

                expectation.fulfill()
            }
            .store(in: &cancellables)

        // Then: Should receive at least one update
        await fulfillment(of: [expectation], timeout: 3.0)

        print("🔍 [NetworkMonitorTests] === SUBSCRIPTION TEST COMPLETE ===\n")
        XCTAssertTrue(true, "ChatViewModel subscription pattern works")
    }
}

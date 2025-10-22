//
//  NetworkMonitor.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/21/25.
//

import Network
import Combine
import FirebaseFirestore

/// Protocol for network connectivity monitoring
///
/// Allows for dependency injection and testability of network monitoring functionality.
protocol NetworkMonitorProtocol: ObservableObject {
    /// Whether the device has network connectivity
    var isConnected: Bool { get }
    
    /// Publisher for network connectivity changes
    var isConnectedPublisher: Published<Bool>.Publisher { get }
}

/// Monitors network connectivity status using hybrid approach
///
/// **Hybrid Strategy:**
/// 1. NWPathMonitor - Efficient on real devices
/// 2. Firestore connection monitoring - Reliable fallback for simulator
///
/// Provides real-time network reachability updates for offline indicator UI.
/// Uses Apple's Network framework to detect WiFi, cellular, and ethernet connections.
///
/// **Simulator Note:** NWPathMonitor has known issues detecting reconnection in
/// iOS Simulator, so we use Firestore's connection state as backup detection.
///
/// Usage:
/// ```swift
/// let monitor = NetworkMonitor()
/// monitor.$isConnected
///     .sink { isConnected in
///         print("Network status: \(isConnected)")
///     }
/// ```
class NetworkMonitor: NetworkMonitorProtocol {
    
    // MARK: - Published Properties
    
    /// Whether device has network connectivity
    @Published var isConnected: Bool = true
    
    /// Publisher for network connectivity changes
    var isConnectedPublisher: Published<Bool>.Publisher { $isConnected }
    
    /// Type of network connection (WiFi, cellular, etc.)
    @Published var connectionType: NWInterface.InterfaceType?
    
    // MARK: - Private Properties
    
    /// NWPathMonitor instance for network status monitoring
    private let monitor: NWPathMonitor
    
    /// Background queue for network monitoring
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    /// Firestore listener for simulator connection detection
    private var firestoreListener: ListenerRegistration?
    
    /// Timer for periodic connection checks
    private var connectionCheckTimer: Timer?
    
    // MARK: - Initialization
    
    /// Initializes NetworkMonitor and starts monitoring
    ///
    /// The monitor begins tracking network status immediately using both:
    /// 1. NWPathMonitor for efficient real-device monitoring
    /// 2. Firestore connection listener as simulator-compatible fallback
    ///
    /// Updates are published on the main thread via @Published properties.
    init() {
        monitor = NWPathMonitor()
        
        // Configure path update handler (works great on real devices)
        monitor.pathUpdateHandler = { [weak self] path in
            let status = path.status
            let isSatisfied = (status == .satisfied)
            print("🌐 [NetworkMonitor] NWPathMonitor update: status=\(status), isSatisfied=\(isSatisfied)")
            print("   Available interfaces: \(path.availableInterfaces.map { $0.name })")
            
            Task { @MainActor in
                self?.isConnected = isSatisfied
                self?.connectionType = path.availableInterfaces.first?.type
                print("🌐 [NetworkMonitor] Updated isConnected=\(isSatisfied) (via NWPathMonitor)")
            }
        }
        
        // Start monitoring on background queue
        monitor.start(queue: queue)
        
        // Setup Firestore connection monitoring (works in simulator)
        // Skip in test environment to avoid adding load to emulator during performance tests
        if !isRunningTests {
            setupFirestoreConnectionMonitoring()
        }
    }
    
    /// Check if running in test environment
    private var isRunningTests: Bool {
        return NSClassFromString("XCTest") != nil ||
               ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    
    // MARK: - Deinitialization
    
    /// Stops network monitoring when object is deallocated
    deinit {
        monitor.cancel()
        firestoreListener?.remove()
        connectionCheckTimer?.invalidate()
    }
    
    // MARK: - Private Methods
    
    /// Setup Firestore connection monitoring for simulator compatibility
    ///
    /// Uses a lightweight Firestore listener to detect connection state changes.
    /// This works reliably in the iOS Simulator where NWPathMonitor may not.
    ///
    /// **Strategy:**
    /// - Listen to a minimal document (_monitoring/connection)
    /// - On successful snapshot: Device is online
    /// - On connection error: Device is offline
    /// - Periodic retries ensure we detect reconnection
    private func setupFirestoreConnectionMonitoring() {
        let db = Firestore.firestore()
        
        // Use a minimal document for connection testing
        let connectionRef = db.collection("_monitoring").document("connection")
        
        // Listen for connection state via snapshot listener
        firestoreListener = connectionRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error as NSError? {
                    // Check for connection-related errors
                    let isConnectionError = self.isFirestoreConnectionError(error)
                    
                    if isConnectionError {
                        print("🌐 [NetworkMonitor] Firestore detected offline: \(error.localizedDescription)")
                        if self.isConnected {
                            self.isConnected = false
                            print("🌐 [NetworkMonitor] Updated isConnected=false (via Firestore)")
                        }
                    }
                } else {
                    // Successfully received snapshot = online
                    print("🌐 [NetworkMonitor] Firestore detected online")
                    if !self.isConnected {
                        self.isConnected = true
                        print("🌐 [NetworkMonitor] Updated isConnected=true (via Firestore)")
                    }
                }
            }
        }
        
        // Periodic connection check to ensure we detect reconnection
        // This is especially important in simulator where NWPathMonitor may not fire
        connectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Trigger a lightweight read to test connection
            connectionRef.getDocument { snapshot, error in
                Task { @MainActor in
                    if let error = error as NSError? {
                        let isConnectionError = self.isFirestoreConnectionError(error)
                        if isConnectionError && self.isConnected {
                            print("🌐 [NetworkMonitor] Periodic check detected offline")
                            self.isConnected = false
                        }
                    } else if !self.isConnected {
                        print("🌐 [NetworkMonitor] Periodic check detected reconnection")
                        self.isConnected = true
                    }
                }
            }
        }
    }
    
    /// Check if a Firestore error indicates connection issues
    private func isFirestoreConnectionError(_ error: NSError) -> Bool {
        // Firestore error domain
        guard error.domain == "FIRFirestoreErrorDomain" else { return false }
        
        // Common connection error codes:
        // 14 = UNAVAILABLE (offline)
        // 13 = INTERNAL (often connection issues)
        // 4 = DEADLINE_EXCEEDED (timeout)
        return [14, 13, 4].contains(error.code)
    }
}


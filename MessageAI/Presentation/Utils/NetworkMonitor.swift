//
//  NetworkMonitor.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/21/25.
//

import Network
import Combine

/// Protocol for network connectivity monitoring
///
/// Allows for dependency injection and testability of network monitoring functionality.
protocol NetworkMonitorProtocol: ObservableObject {
    /// Whether the device has network connectivity
    var isConnected: Bool { get }
    
    /// Publisher for network connectivity changes
    var isConnectedPublisher: Published<Bool>.Publisher { get }
}

/// Monitors network connectivity status using NWPathMonitor
///
/// Provides real-time network reachability updates for offline indicator UI.
/// Uses Apple's Network framework to detect WiFi, cellular, and ethernet connections.
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
    
    // MARK: - Initialization
    
    /// Initializes NetworkMonitor and starts monitoring
    ///
    /// The monitor begins tracking network status immediately.
    /// Updates are published on the main thread via @Published properties.
    init() {
        monitor = NWPathMonitor()
        
        // Configure path update handler
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = (path.status == .satisfied)
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        
        // Start monitoring on background queue
        monitor.start(queue: queue)
    }
    
    // MARK: - Deinitialization
    
    /// Stops network monitoring when object is deallocated
    deinit {
        monitor.cancel()
    }
}


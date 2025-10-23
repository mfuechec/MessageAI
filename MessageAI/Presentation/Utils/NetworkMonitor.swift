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
    /// Whether the device has network connectivity (OS-level)
    var isConnected: Bool { get }

    /// Publisher for network connectivity changes
    var isConnectedPublisher: Published<Bool>.Publisher { get }

    /// Whether Firestore is connected and syncing
    var isFirestoreConnected: Bool { get }

    /// Publisher for Firestore connectivity changes
    var isFirestoreConnectedPublisher: Published<Bool>.Publisher { get }

    /// Effective connectivity state (source of truth combining OS and Firestore)
    var isEffectivelyConnected: Bool { get }
}

/// Monitors network connectivity status using Apple's Network framework and Firestore metadata
///
/// Provides real-time network reachability updates for offline indicator UI.
/// Uses `NWPathMonitor` to detect WiFi, cellular, and ethernet connections.
/// Also monitors Firestore connection state via metadata change listeners.
///
/// **Note:** This is the standard Apple-recommended approach for network monitoring.
/// Works reliably on real devices. Simulator may have quirks during development.
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

    /// Whether device has network connectivity (OS-level)
    @Published var isConnected: Bool = true {
        didSet {
            print("🌐 [NetworkMonitor] OS isConnected changed: \(oldValue) -> \(isConnected)")
            checkForConflicts()
        }
    }

    /// Publisher for network connectivity changes
    var isConnectedPublisher: Published<Bool>.Publisher { $isConnected }

    /// Whether Firestore is connected and syncing
    @Published var isFirestoreConnected: Bool = true {
        didSet {
            print("🔥 [NetworkMonitor] Firestore isConnected changed: \(oldValue) -> \(isFirestoreConnected)")
            if !oldValue && isFirestoreConnected {
                print("🔥 [NetworkMonitor] ✅ FIRESTORE RECONNECTED - was offline, now online")
            } else if oldValue && !isFirestoreConnected {
                print("🔥 [NetworkMonitor] ❌ FIRESTORE DISCONNECTED - was online, now offline")
            }
            checkForConflicts()
        }
    }

    /// Publisher for Firestore connectivity changes
    var isFirestoreConnectedPublisher: Published<Bool>.Publisher { $isFirestoreConnected }

    /// Effective connectivity state - combines OS and Firestore state
    ///
    /// This is the "source of truth" for the app. The rules:
    /// - If Firestore is connected, we're truly online (even if OS network flickers)
    /// - If Firestore is disconnected, we're offline (regardless of OS network)
    /// - Firestore connection is the more accurate indicator for app functionality
    var isEffectivelyConnected: Bool {
        return isFirestoreConnected
    }

    /// Type of network connection (WiFi, cellular, etc.)
    @Published var connectionType: NWInterface.InterfaceType?

    // MARK: - Private Properties

    /// NWPathMonitor instance for network status monitoring
    private let monitor: NWPathMonitor

    /// Background queue for network monitoring
    private let queue = DispatchQueue(label: "NetworkMonitor")

    /// Firestore snapshot listener for metadata changes
    private var firestoreListener: ListenerRegistration?

    // MARK: - Initialization

    /// Initializes NetworkMonitor and starts monitoring
    ///
    /// The monitor begins tracking network status immediately using `NWPathMonitor`
    /// and Firestore metadata change listeners.
    /// Updates are published on the main thread via @Published properties.
    init() {
        print("🌐 [NetworkMonitor] Initializing NetworkMonitor")
        monitor = NWPathMonitor()

        // Configure path update handler
        monitor.pathUpdateHandler = { [weak self] path in
            let status = path.status
            let isSatisfied = (status == .satisfied)
            let interfaces = path.availableInterfaces.map { $0.name }.joined(separator: ", ")

            print("🌐 [NetworkMonitor] Path update - status: \(status), satisfied: \(isSatisfied), interfaces: [\(interfaces)]")

            Task { @MainActor in
                self?.isConnected = isSatisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }

        // Start monitoring on background queue
        monitor.start(queue: queue)
        print("🌐 [NetworkMonitor] NWPathMonitor started")

        // Start Firestore connectivity monitoring
        setupFirestoreMonitoring()
    }

    // MARK: - Private Methods

    /// Checks for conflicts between OS network state and Firestore state
    ///
    /// Logs warnings when the two monitoring systems disagree. This helps debug
    /// edge cases like Firestore connection issues when network is up.
    private func checkForConflicts() {
        // Conflict: OS says online, but Firestore is offline
        if isConnected && !isFirestoreConnected {
            print("⚠️ [NetworkMonitor] CONFLICT: OS network is UP ✅, but Firestore is DOWN ❌")
            print("   This could mean:")
            print("   - Firestore backend issues")
            print("   - Firestore is reconnecting")
            print("   - Firewall/VPN blocking Firestore")
        }

        // Conflict: OS says offline, but Firestore is online (rare, but possible during transitions)
        if !isConnected && isFirestoreConnected {
            print("⚠️ [NetworkMonitor] CONFLICT: OS network is DOWN ❌, but Firestore is UP ✅")
            print("   This is unusual and may indicate:")
            print("   - Firestore using cached connection")
            print("   - Race condition during network transition")
            print("   - OS network detection delay")
        }

        // Happy path: both agree
        if isConnected && isFirestoreConnected {
            print("✅ [NetworkMonitor] AGREEMENT: Both OS network and Firestore are ONLINE")
        } else if !isConnected && !isFirestoreConnected {
            print("✅ [NetworkMonitor] AGREEMENT: Both OS network and Firestore are OFFLINE")
        }
    }

    /// Sets up Firestore metadata change listener to detect connectivity
    ///
    /// Monitors a dummy Firestore query with metadata changes to detect when
    /// Firestore transitions between online and offline states. This is more
    /// accurate than OS-level network monitoring for detecting Firestore reconnection.
    private func setupFirestoreMonitoring() {
        print("🔥 [NetworkMonitor] Setting up Firestore metadata monitoring")

        let db = Firestore.firestore()

        // Listen to a lightweight query with metadata changes
        // We use a simple query to minimize data transfer
        firestoreListener = db.collection("_connection_test")
            .limit(to: 1)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in

                guard let self = self else { return }

                if let error = error {
                    print("🔥 [NetworkMonitor] ⚠️ Firestore listener error: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.isFirestoreConnected = false
                    }
                    return
                }

                guard let snapshot = snapshot else {
                    print("🔥 [NetworkMonitor] ⚠️ Firestore snapshot is nil")
                    return
                }

                let metadata = snapshot.metadata

                // Log detailed metadata for debugging
                print("🔥 [NetworkMonitor] Firestore metadata update:")
                print("   - hasPendingWrites: \(metadata.hasPendingWrites)")
                print("   - isFromCache: \(metadata.isFromCache)")

                // Firestore is connected if data is NOT from cache
                // (or if it's from cache but has no pending writes, meaning it's up to date)
                let isConnected = !metadata.isFromCache

                print("🔥 [NetworkMonitor] Firestore connection state: \(isConnected ? "ONLINE ✅" : "OFFLINE ❌")")

                Task { @MainActor in
                    self.isFirestoreConnected = isConnected
                }
            }

        print("🔥 [NetworkMonitor] Firestore metadata listener registered")
    }

    // MARK: - Deinitialization

    /// Stops network monitoring when object is deallocated
    deinit {
        monitor.cancel()
        firestoreListener?.remove()
        print("🌐 [NetworkMonitor] NetworkMonitor deallocated (NWPathMonitor and Firestore listener stopped)")
    }
}


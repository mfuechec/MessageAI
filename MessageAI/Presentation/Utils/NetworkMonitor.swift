//
//  NetworkMonitor.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/21/25.
//

import Network
import Combine
import FirebaseFirestore
import FirebaseAuth

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

    /// Publisher for effective connectivity changes (source of truth)
    /// This is the recommended publisher to use for UI state management
    var isEffectivelyConnectedPublisher: AnyPublisher<Bool, Never> { get }

    /// Retry setting up Firestore monitoring (call after user authentication)
    func retryFirestoreMonitoring()
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
            // Only log real transitions after we've received first snapshot
            if hasReceivedFirstSnapshot {
                print("🔥 [NetworkMonitor] Firestore isConnected changed: \(oldValue) -> \(isFirestoreConnected)")
                if !oldValue && isFirestoreConnected {
                    print("🔥 [NetworkMonitor] ✅ FIRESTORE RECONNECTED - was offline, now online")
                } else if oldValue && !isFirestoreConnected {
                    print("🔥 [NetworkMonitor] ❌ FIRESTORE DISCONNECTED - was online, now offline")
                }
                checkForConflicts()
            }
        }
    }

    /// Publisher for Firestore connectivity changes
    var isFirestoreConnectedPublisher: Published<Bool>.Publisher { $isFirestoreConnected }

    /// Effective connectivity state - combines OS and Firestore state
    ///
    /// This is the "source of truth" for the app. The rules:
    /// - Trust Firestore as the PRIMARY authority (it proves we can actually sync)
    /// - But the publisher emits on BOTH OS and Firestore changes for immediate UI updates
    /// - This gives us: fast offline detection (OS) + accurate online detection (Firestore)
    var isEffectivelyConnected: Bool {
        // Trust Firestore as the authority
        // If Firestore says online, we're online (even if OS lags in Simulator)
        // If Firestore says offline, we're offline
        return isFirestoreConnected
    }

    /// Publisher for effective connectivity changes (source of truth)
    /// This is the recommended publisher to use for UI state management
    /// Combines both OS and Firestore connectivity signals
    var isEffectivelyConnectedPublisher: AnyPublisher<Bool, Never> {
        // Emit when EITHER OS or Firestore changes (for immediate UI updates)
        // But always return Firestore state (the authority)
        // This gives us:
        // - Immediate emission when OS detects offline (fast UI update)
        // - Correct value from Firestore (accurate connectivity)
        Publishers.CombineLatest($isConnected, $isFirestoreConnected)
            .map { _, isFirestoreConnected in
                // Always trust Firestore as the authority
                return isFirestoreConnected
            }
            .eraseToAnyPublisher()
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

    /// Track if we've received the first Firestore snapshot (to avoid false offline banner on launch)
    private var hasReceivedFirstSnapshot = false

    /// Grace period after app launch (prevents false offline banner during initial cache loads)
    private var appLaunchTime = Date()
    private let startupGracePeriodSeconds: TimeInterval = 3.0

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

        // Remove any existing listener (handles logout/login scenarios)
        if let existingListener = firestoreListener {
            existingListener.remove()
            print("🔥 [NetworkMonitor] Removed existing Firestore listener")
            firestoreListener = nil
        }

        let db = Firestore.firestore()

        // Listen to a lightweight query with metadata changes
        // Use authenticated user's document to test connection (always has read permission)
        guard let userId = Auth.auth().currentUser?.uid else {
            print("🔥 [NetworkMonitor] ⚠️ No authenticated user - cannot set up connection listener")
            return
        }

        // Reset state for this monitoring session
        // This ensures the first snapshot from THIS listener is treated specially,
        // even if the user logged out and logged back in (reusing the same NetworkMonitor instance)
        hasReceivedFirstSnapshot = false
        appLaunchTime = Date()
        print("🔥 [NetworkMonitor] Reset monitoring state (first snapshot flag + grace period timer)")

        firestoreListener = db.collection("users")
            .document(userId)
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
                print("🔥 [NetworkMonitor] Firestore metadata update (first: \(!self.hasReceivedFirstSnapshot)):")
                print("   - hasPendingWrites: \(metadata.hasPendingWrites)")
                print("   - isFromCache: \(metadata.isFromCache)")

                // Firestore is connected if data is NOT from cache
                // (or if it's from cache but has no pending writes, meaning it's up to date)
                let isConnected = !metadata.isFromCache

                print("🔥 [NetworkMonitor] Firestore connection state: \(isConnected ? "ONLINE ✅" : "OFFLINE ❌")")

                Task { @MainActor in
                    // SPECIAL CASE: First snapshot ever received
                    // This snapshot often comes from cache and should be ignored if offline,
                    // regardless of timing (user might spend time on profile setup, etc.)
                    if !self.hasReceivedFirstSnapshot {
                        self.hasReceivedFirstSnapshot = true
                        print("🔥 [NetworkMonitor] 🎯 FIRST SNAPSHOT RECEIVED (fromCache: \(metadata.isFromCache))")

                        if isConnected {
                            // Online state: update immediately
                            print("🔥 [NetworkMonitor] ✅ First snapshot shows ONLINE - updating immediately")
                            self.isFirestoreConnected = true
                        } else {
                            // Offline state: UNCONDITIONALLY IGNORE (always from cache on first snapshot)
                            print("🔥 [NetworkMonitor] 🚫 First snapshot shows OFFLINE - ignoring unconditionally (cached data)")
                            // Don't update - stay at default true
                        }
                        return
                    }

                    // SUBSEQUENT SNAPSHOTS: Use time-based grace period
                    let timeSinceLaunch = Date().timeIntervalSince(self.appLaunchTime)
                    if timeSinceLaunch < self.startupGracePeriodSeconds {
                        if isConnected {
                            // Online state: update immediately (even during grace period)
                            print("🔥 [NetworkMonitor] ⏳ Within grace period (\(String(format: "%.1f", timeSinceLaunch))s) - online state, updating immediately")
                            self.isFirestoreConnected = true
                        } else {
                            // Offline state: ignore during grace period (likely from cache)
                            print("🔥 [NetworkMonitor] ⏳ Within grace period (\(String(format: "%.1f", timeSinceLaunch))s) - ignoring offline state (likely cached)")
                            // Don't update - stay at default true
                        }
                        return
                    }

                    // After grace period: update normally
                    print("🔥 [NetworkMonitor] ⏱️ After grace period - updating to \(isConnected ? "ONLINE ✅" : "OFFLINE ❌")")
                    self.isFirestoreConnected = isConnected
                }
            }

        print("🔥 [NetworkMonitor] Firestore metadata listener registered")
    }

    // MARK: - Public Methods

    /// Retry setting up Firestore monitoring (call after user authentication)
    ///
    /// This should be called after a user logs in if the NetworkMonitor was created before authentication.
    /// It will set up the Firestore metadata listener for the authenticated user.
    /// Also used when switching accounts (logout/login) to set up listener for new user.
    func retryFirestoreMonitoring() {
        // Only set up if user is authenticated
        guard Auth.auth().currentUser != nil else {
            print("🔥 [NetworkMonitor] Cannot retry - no authenticated user")
            return
        }

        print("🔥 [NetworkMonitor] Setting up Firestore monitoring for authenticated user")
        setupFirestoreMonitoring()
    }

    // MARK: - Deinitialization

    /// Stops network monitoring when object is deallocated
    deinit {
        monitor.cancel()
        firestoreListener?.remove()
        print("🌐 [NetworkMonitor] NetworkMonitor deallocated (NWPathMonitor and Firestore listener stopped)")
    }
}


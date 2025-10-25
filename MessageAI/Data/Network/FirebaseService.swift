//
//  FirebaseService.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/20/25.
//

import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import FirebaseFunctions

/// Central Firebase service manager
///
/// Provides a singleton interface to all Firebase services (Firestore, Auth, Storage).
/// Handles environment-specific configuration and enables offline persistence for Firestore.
///
/// Key Features:
/// - Automatic environment detection (dev vs prod)
/// - Firestore offline persistence with unlimited cache
/// - Centralized initialization and configuration
/// - Type-safe access to Firebase services
///
/// Usage:
/// ```swift
/// let db = FirebaseService.shared.firestore
/// let auth = FirebaseService.shared.auth
/// ```
class FirebaseService {
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide Firebase access
    static let shared = FirebaseService()
    
    // MARK: - Services
    
    /// Firestore database instance with offline persistence enabled
    var firestore: Firestore {
        return Firestore.firestore()
    }
    
    /// Firebase Authentication instance
    var auth: Auth {
        return Auth.auth()
    }
    
    /// Firebase Storage instance for file uploads
    var storage: Storage {
        return Storage.storage()
    }
    
    // MARK: - Initialization
    
    /// Internal initializer for testing (allows emulator configuration)
    /// For production code, use FirebaseService.shared
    init() {
        // Default initialization - configure() must be called separately
    }
    
    /// Configure Firebase with environment-specific settings
    ///
    /// This method should be called once at app startup. It:
    /// - Loads GoogleService-Info plist based on current environment
    /// - Enables Firestore offline persistence with unlimited cache
    /// - Optionally configures emulator for testing
    func configure() {
        // Check if already configured
        if FirebaseApp.app() != nil {
            print("⚠️  Firebase already configured")
            return
        }

        // Configure Firebase with environment-specific plist FIRST
        if let filePath = Bundle.main.path(forResource: Environment.current.firebaseConfigFileName, ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: filePath) {
            FirebaseApp.configure(options: options)
        } else {
            fatalError("Failed to load Firebase configuration for \(Environment.current.displayName) environment")
        }

        // Configure Firestore offline persistence
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        Firestore.firestore().settings = settings

        // Use emulator if launch argument is set (AFTER Firebase is configured)
        useEmulator()

        print("✅ Firebase configured for \(Environment.current.displayName) environment")
    }
    
    /// Configure Firebase to use local emulator for testing
    ///
    /// This method checks for the USE_FIREBASE_EMULATOR launch argument and configures
    /// Firebase services to use local emulators instead of production services.
    /// Only works in DEBUG builds.
    func useEmulator() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("USE_FIREBASE_EMULATOR") {
            print("🔥 Using Firebase Emulator")

            // Auth Emulator
            Auth.auth().useEmulator(withHost: "localhost", port: 9099)

            // Firestore Emulator
            let settings = Firestore.firestore().settings
            settings.host = "localhost:8080"
            settings.isSSLEnabled = false
            Firestore.firestore().settings = settings

            // Storage Emulator
            Storage.storage().useEmulator(withHost: "localhost", port: 9199)

            // Cloud Functions Emulator
            Functions.functions().useEmulator(withHost: "localhost", port: 5001)
            print("🔥 Cloud Functions emulator: localhost:5001")
        }
        #endif
    }
}


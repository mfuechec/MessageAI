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
    let firestore: Firestore
    
    /// Firebase Authentication instance
    let auth: Auth
    
    /// Firebase Storage instance for file uploads
    let storage: Storage
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern
    ///
    /// Configures Firebase with environment-specific settings and enables critical features:
    /// - Loads GoogleService-Info plist based on current environment
    /// - Enables Firestore offline persistence with unlimited cache
    /// - Initializes all Firebase services
    private init() {
        // Configure Firebase with environment-specific plist
        if let filePath = Bundle.main.path(forResource: Environment.current.firebaseConfigFileName, ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: filePath) {
            FirebaseApp.configure(options: options)
        } else {
            fatalError("Failed to load Firebase configuration for \(Environment.current.displayName) environment")
        }
        
        // Initialize Firestore with offline persistence
        self.firestore = Firestore.firestore()
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        self.firestore.settings = settings
        
        // Initialize Auth
        self.auth = Auth.auth()
        
        // Initialize Storage
        self.storage = Storage.storage()
        
        print("✅ Firebase configured for \(Environment.current.displayName) environment")
    }
}


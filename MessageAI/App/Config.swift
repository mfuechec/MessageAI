//
//  Config.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/20/25.
//

import Foundation

/// Application environment configuration
///
/// Defines the environment (development or production) and provides environment-specific configuration.
/// Environment is automatically determined based on build configuration:
/// - DEBUG builds use development environment
/// - RELEASE builds use production environment
///
/// This enables safe development without affecting production data and services.
enum Environment {
    case development
    case production
    
    /// Current environment based on build configuration
    /// - Returns: `.development` for DEBUG builds, `.production` for RELEASE builds
    static var current: Environment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    /// Firebase configuration file name for this environment
    /// - Returns: Filename (without .plist extension) for the environment-specific GoogleService-Info file
    var firebaseConfigFileName: String {
        switch self {
        case .development:
            return "GoogleService-Info-Dev"
        case .production:
            return "GoogleService-Info-Prod"
        }
    }
    
    /// Human-readable environment name for logging
    /// - Returns: Display name of the environment
    var displayName: String {
        switch self {
        case .development: return "Development"
        case .production: return "Production"
        }
    }
}


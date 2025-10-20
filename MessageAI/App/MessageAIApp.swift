//
//  MessageAIApp.swift
//  MessageAI
//
//  Created by Mark Fuechec on 10/20/25.
//

import SwiftUI

@main
struct MessageAIApp: App {
    
    /// Initialize Firebase on app launch
    /// FirebaseService.shared triggers Firebase configuration with environment-specific settings
    init() {
        _ = FirebaseService.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

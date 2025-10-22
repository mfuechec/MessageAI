//
//  FailedMessageStore.swift
//  MessageAI
//
//  Local persistence for failed messages (survives app restart)
//

import Foundation

/// Local persistence for failed messages using UserDefaults
///
/// Stores messages that failed to send so they can be retried after app restart
/// or when network connection is restored.
class FailedMessageStore {
    private let userDefaults = UserDefaults.standard
    private let key = "failedMessages"
    
    /// Save failed message to UserDefaults
    ///
    /// If message already exists (same ID), it will be updated.
    func save(_ message: Message) {
        var failedMessages = loadAll()
        
        // Add or update message
        if let index = failedMessages.firstIndex(where: { $0.id == message.id }) {
            failedMessages[index] = message
            print("💾 Updated failed message: \(message.id)")
        } else {
            failedMessages.append(message)
            print("💾 Saved failed message: \(message.id)")
        }
        
        // Encode and save
        if let encoded = try? JSONEncoder().encode(failedMessages) {
            userDefaults.set(encoded, forKey: key)
        } else {
            print("❌ Failed to encode failed messages")
        }
    }
    
    /// Load all failed messages from UserDefaults
    func loadAll() -> [Message] {
        guard let data = userDefaults.data(forKey: key),
              let messages = try? JSONDecoder().decode([Message].self, from: data) else {
            return []
        }
        return messages
    }
    
    /// Remove failed message after successful retry or delete
    func remove(_ messageId: String) {
        var failedMessages = loadAll()
        failedMessages.removeAll { $0.id == messageId }
        
        if let encoded = try? JSONEncoder().encode(failedMessages) {
            userDefaults.set(encoded, forKey: key)
            print("🗑️ Removed failed message: \(messageId)")
        }
    }
    
    /// Clear all failed messages (for testing)
    func clearAll() {
        userDefaults.removeObject(forKey: key)
        print("🗑️ Cleared all failed messages")
    }
}


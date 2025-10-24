import Foundation
import FirebaseFirestore
import Combine

/*
 Firestore Collection: users/{userId}/ai_notification_preferences

 Structure:
 - Subcollection under users/{userId}
 - Document ID: "preferences" (single preferences document per user)
 - Fields: All NotificationPreferences entity properties

 Queries:
 - Get preferences: document("preferences").getDocument()
 - Observe changes: Real-time listener on preferences document
 */

/// Firebase implementation of NotificationPreferencesRepositoryProtocol (Epic 6 - Story 6.4)
///
/// Manages user notification preferences in Firestore subcollection
final class FirebaseNotificationPreferencesRepository: NotificationPreferencesRepositoryProtocol {

    // MARK: - Properties

    private let db: Firestore
    private var activeListeners: [ListenerRegistration] = []

    // MARK: - Initialization

    init(firebaseService: FirebaseService) {
        self.db = firebaseService.firestore
    }

    deinit {
        // Clean up listeners to prevent memory leaks
        activeListeners.forEach { $0.remove() }
    }

    // MARK: - NotificationPreferencesRepositoryProtocol

    func getPreferences(userId: String) async throws -> NotificationPreferences {
        do {
            let document = try await db.collection("users")
                .document(userId)
                .collection("ai_notification_preferences")
                .document("preferences")
                .getDocument()

            guard document.exists else {
                print("❌ Notification preferences not found for user: \(userId)")
                throw RepositoryError.notFound
            }

            guard let data = document.data() else {
                print("❌ Preferences document has no data: \(userId)")
                throw RepositoryError.decodingError(
                    NSError(domain: "FirebaseNotificationPreferencesRepository", code: -1)
                )
            }

            let preferences = try Firestore.Decoder.default.decode(NotificationPreferences.self, from: data)
            print("✅ Notification preferences fetched for user: \(userId)")
            return preferences
        } catch let error as RepositoryError {
            throw error
        } catch let error as DecodingError {
            print("❌ Get preferences failed (decoding): \(error.localizedDescription)")
            throw RepositoryError.decodingError(error)
        } catch {
            print("❌ Get preferences failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }

    func savePreferences(_ preferences: NotificationPreferences) async throws {
        do {
            var preferencesData = preferences
            preferencesData.updatedAt = Date()

            let data = try Firestore.Encoder.default.encode(preferencesData)

            try await db.collection("users")
                .document(preferences.userId)
                .collection("ai_notification_preferences")
                .document("preferences")
                .setData(data, merge: true)

            print("✅ Notification preferences saved for user: \(preferences.userId)")
        } catch let error as EncodingError {
            print("❌ Save preferences failed (encoding): \(error.localizedDescription)")
            throw RepositoryError.encodingError(error)
        } catch {
            print("❌ Save preferences failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }

    func observePreferences(userId: String) -> AnyPublisher<NotificationPreferences, Never> {
        // Don't set up listener if userId is empty (prevents "document path cannot be empty" error)
        guard !userId.isEmpty else {
            print("⚠️ Cannot observe preferences: userId is empty")
            return Empty<NotificationPreferences, Never>().eraseToAnyPublisher()
        }

        let subject = PassthroughSubject<NotificationPreferences, Never>()

        let listener = db.collection("users")
            .document(userId)
            .collection("ai_notification_preferences")
            .document("preferences")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    let nsError = error as NSError

                    // Check if this is a permission error (expected on logout)
                    if nsError.domain == FirestoreErrorDomain &&
                       nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
                        print("ℹ️ Preferences listener permission denied (user likely logged out)")
                        return
                    }

                    // Log other errors (unexpected)
                    print("❌ Preferences observation error: \(error.localizedDescription)")
                    return
                }

                guard let data = snapshot?.data() else {
                    print("⚠️ Preferences snapshot has no data")
                    return
                }

                do {
                    let preferences = try Firestore.Decoder.default.decode(NotificationPreferences.self, from: data)
                    subject.send(preferences)
                } catch {
                    print("❌ Failed to decode preferences update: \(error.localizedDescription)")
                }
            }

        activeListeners.append(listener)

        return subject
            .handleEvents(receiveCancel: {
                listener.remove()
            })
            .eraseToAnyPublisher()
    }

    func isEnabled(userId: String) async throws -> Bool {
        do {
            let preferences = try await getPreferences(userId: userId)
            return preferences.enabled
        } catch {
            // If preferences don't exist, smart notifications are not enabled
            return false
        }
    }

    func enableSmartNotifications(
        userId: String,
        defaultPreferences: NotificationPreferences? = nil
    ) async throws {
        let basePrefs = defaultPreferences ?? NotificationPreferences.default

        let preferences = NotificationPreferences(
            userId: userId,
            enabled: true,
            pauseThresholdSeconds: basePrefs.pauseThresholdSeconds,
            activeConversationThreshold: basePrefs.activeConversationThreshold,
            quietHoursStart: basePrefs.quietHoursStart,
            quietHoursEnd: basePrefs.quietHoursEnd,
            timezone: basePrefs.timezone,
            priorityKeywords: basePrefs.priorityKeywords,
            maxAnalysesPerHour: basePrefs.maxAnalysesPerHour,
            fallbackStrategy: basePrefs.fallbackStrategy,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await savePreferences(preferences)
        print("✅ Smart notifications enabled for user: \(userId)")
    }

    func disableSmartNotifications(userId: String) async throws {
        var preferences = try await getPreferences(userId: userId)
        preferences.enabled = false
        preferences.updatedAt = Date()

        try await savePreferences(preferences)
        print("✅ Smart notifications disabled for user: \(userId)")
    }

    func deletePreferences(userId: String) async throws {
        do {
            try await db.collection("users")
                .document(userId)
                .collection("ai_notification_preferences")
                .document("preferences")
                .delete()

            print("✅ Notification preferences deleted for user: \(userId)")
        } catch {
            print("❌ Delete preferences failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
}

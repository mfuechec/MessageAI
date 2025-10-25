import Foundation
import Combine
import UIKit
import FirebaseFirestore
import FirebaseAuth

/*
 Google Calendar API Integration

 OAuth Scopes Required:
 - https://www.googleapis.com/auth/calendar (read/write calendar events)
 - https://www.googleapis.com/auth/calendar.events (manage events)
 - https://www.googleapis.com/auth/calendar.readonly (read-only for availability)

 API Endpoints:
 - Create Event: POST /calendar/v3/calendars/primary/events
 - List Events: GET /calendar/v3/calendars/primary/events
 - Update Event: PUT /calendar/v3/calendars/primary/events/{eventId}
 - Delete Event: DELETE /calendar/v3/calendars/primary/events/{eventId}
 - FreeBusy Query: POST /calendar/v3/freeBusy

 NOTE: This implementation requires adding Google Sign-In SDK dependencies:
 - GoogleSignIn (~> 7.0)
 - GoogleAPIClientForREST/Calendar (~> 3.0)

 Add via Xcode: File > Add Package Dependencies
 - https://github.com/google/GoogleSignIn-iOS
 - https://github.com/google/google-api-objectivec-client-for-rest
*/

/// Google Calendar implementation of CalendarRepositoryProtocol
///
/// Manages OAuth authentication and calendar operations via Google Calendar API.
/// Stores refresh tokens securely in Firestore user document.
final class GoogleCalendarRepository: CalendarRepositoryProtocol {

    // MARK: - Properties

    private let firestore: Firestore
    private let userRepository: UserRepositoryProtocol
    private let authHelper: GoogleCalendarAuthHelper
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    private let connectionStatusSubject = CurrentValueSubject<Bool, Never>(false)

    // Calendar API configuration
    private let calendarAPIBaseURL = "https://www.googleapis.com/calendar/v3"

    // MARK: - Initialization

    init(firebaseService: FirebaseService, userRepository: UserRepositoryProtocol) {
        self.firestore = firebaseService.firestore
        self.userRepository = userRepository
        self.authHelper = GoogleCalendarAuthHelper(firestore: firebaseService.firestore)

        // Restore previous Google Sign-In session on init
        Task {
            try? await authHelper.restorePreviousSignIn()
            let connected = await isConnected()
            connectionStatusSubject.send(connected)
        }
    }

    // MARK: - CalendarRepositoryProtocol

    func authenticateWithGoogle() async throws -> Bool {
        guard currentUserId != nil else {
            throw CalendarError.notAuthenticated
        }

        // Get root view controller to present sign-in UI
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw CalendarError.apiError("No view controller available for sign-in")
        }

        // Use auth helper to handle OAuth flow
        let success = try await authHelper.authenticateWithGoogle(from: rootViewController)

        if success {
            connectionStatusSubject.send(true)
        }

        return success
    }

    func disconnectGoogleCalendar() async throws {
        guard let userId = currentUserId else {
            throw CalendarError.notAuthenticated
        }

        // Use auth helper to revoke token and clear data
        try await authHelper.disconnect()

        connectionStatusSubject.send(false)
        print("✅ Google Calendar disconnected for user: \(userId)")
    }

    func isConnected() async -> Bool {
        guard let userId = currentUserId else {
            return false
        }

        do {
            let doc = try await firestore.collection("users").document(userId).getDocument()
            return doc.data()?["googleCalendarConnected"] as? Bool ?? false
        } catch {
            print("❌ Failed to check calendar connection: \(error.localizedDescription)")
            return false
        }
    }

    func createEvent(_ event: CalendarEvent) async throws -> CalendarEvent {
        guard await isConnected() else {
            throw CalendarError.notConnected
        }

        let accessToken = try await getAccessToken()

        // Build Google Calendar API request
        let url = URL(string: "\(calendarAPIBaseURL)/calendars/primary/events")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert domain entity to Google Calendar API format
        let apiEvent = GoogleCalendarEventMapper.toAPIFormat(event)
        request.httpBody = try JSONEncoder().encode(apiEvent)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CalendarError.apiError("Failed to create event")
        }

        let createdEvent = try JSONDecoder().decode(GoogleCalendarEventAPI.self, from: data)
        return GoogleCalendarEventMapper.toDomain(createdEvent)
    }

    func getEvents(from startDate: Date, to endDate: Date, maxResults: Int = 50) async throws -> [CalendarEvent] {
        guard await isConnected() else {
            throw CalendarError.notConnected
        }

        let accessToken = try await getAccessToken()

        // Build query parameters
        let dateFormatter = ISO8601DateFormatter()
        let timeMin = dateFormatter.string(from: startDate)
        let timeMax = dateFormatter.string(from: endDate)

        var components = URLComponents(string: "\(calendarAPIBaseURL)/calendars/primary/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: timeMin),
            URLQueryItem(name: "timeMax", value: timeMax),
            URLQueryItem(name: "maxResults", value: "\(maxResults)"),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CalendarError.apiError("Failed to fetch events")
        }

        let apiResponse = try JSONDecoder().decode(GoogleCalendarEventsListResponse.self, from: data)
        return apiResponse.items.map { GoogleCalendarEventMapper.toDomain($0) }
    }

    func updateEvent(_ event: CalendarEvent) async throws {
        guard await isConnected() else {
            throw CalendarError.notConnected
        }

        let accessToken = try await getAccessToken()

        let url = URL(string: "\(calendarAPIBaseURL)/calendars/primary/events/\(event.id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let apiEvent = GoogleCalendarEventMapper.toAPIFormat(event)
        request.httpBody = try JSONEncoder().encode(apiEvent)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CalendarError.apiError("Failed to update event")
        }
    }

    func deleteEvent(eventId: String) async throws {
        guard await isConnected() else {
            throw CalendarError.notConnected
        }

        let accessToken = try await getAccessToken()

        let url = URL(string: "\(calendarAPIBaseURL)/calendars/primary/events/\(eventId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CalendarError.apiError("Failed to delete event")
        }
    }

    func getAvailability(
        for userEmail: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> CalendarAvailability {
        guard await isConnected() else {
            throw CalendarError.notConnected
        }

        let accessToken = try await getAccessToken()

        // Use FreeBusy API endpoint
        let url = URL(string: "\(calendarAPIBaseURL)/freeBusy")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let dateFormatter = ISO8601DateFormatter()
        let requestBody: [String: Any] = [
            "timeMin": dateFormatter.string(from: startDate),
            "timeMax": dateFormatter.string(from: endDate),
            "items": [["id": userEmail]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CalendarError.apiError("Failed to fetch availability")
        }

        let apiResponse = try JSONDecoder().decode(GoogleFreeBusyResponse.self, from: data)
        return GoogleCalendarAvailabilityMapper.toDomain(
            apiResponse,
            userId: userEmail,
            queriedFrom: startDate,
            queriedTo: endDate
        )
    }

    func getAvailabilityForMultipleUsers(
        userEmails: [String],
        from startDate: Date,
        to endDate: Date
    ) async throws -> [CalendarAvailability] {
        // Fetch availability for all users in parallel
        return try await withThrowingTaskGroup(of: CalendarAvailability.self) { group in
            for email in userEmails {
                group.addTask {
                    try await self.getAvailability(for: email, from: startDate, to: endDate)
                }
            }

            var availabilities: [CalendarAvailability] = []
            for try await availability in group {
                availabilities.append(availability)
            }
            return availabilities
        }
    }

    func observeConnectionStatus() -> AnyPublisher<Bool, Never> {
        connectionStatusSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Helpers

    /// Get OAuth access token (refresh if needed)
    private func getAccessToken() async throws -> String {
        return try await authHelper.getAccessToken()
    }
}

// MARK: - Error Types

enum CalendarError: LocalizedError {
    case notAuthenticated
    case notConnected
    case apiError(String)
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User must be authenticated with Firebase"
        case .notConnected:
            return "Google Calendar not connected. Please connect in Settings."
        case .apiError(let message):
            return "Calendar API error: \(message)"
        case .notImplemented(let message):
            return message
        }
    }
}

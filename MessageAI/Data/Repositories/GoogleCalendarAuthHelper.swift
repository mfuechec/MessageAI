import Foundation
import GoogleSignIn
import FirebaseAuth
import FirebaseFirestore

/// Helper for Google Calendar OAuth authentication
///
/// This class handles the Google Sign-In flow specifically for Calendar API access.
/// Separates OAuth logic from the main repository for better testability.
class GoogleCalendarAuthHelper {

    private let firestore: Firestore
    private let oauthScopes = [
        "https://www.googleapis.com/auth/calendar",
        "https://www.googleapis.com/auth/calendar.events"
    ]

    init(firestore: Firestore) {
        self.firestore = firestore
    }

    /// Initiate Google Sign-In flow for Calendar access
    /// - Parameter presentingViewController: The view controller to present sign-in UI from
    /// - Returns: True if authentication successful
    func authenticateWithGoogle(from presentingViewController: UIViewController?) async throws -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw CalendarAuthError.notAuthenticated
        }

        // Get Client ID from GoogleService-Info.plist
        guard let clientID = getClientID() else {
            throw CalendarAuthError.missingClientID
        }

        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Check if we need to present UI or can restore silently
        let result: GIDSignInResult

        if let previousUser = GIDSignIn.sharedInstance.currentUser {
            // Try to restore previous session with calendar scopes
            guard let presentingVC = presentingViewController else {
                throw CalendarAuthError.noPresentingViewController
            }
            result = try await previousUser.addScopes(oauthScopes, presenting: presentingVC)
        } else {
            // Fresh sign-in required
            guard let presentingVC = presentingViewController else {
                throw CalendarAuthError.noPresentingViewController
            }

            result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingVC,
                hint: nil,
                additionalScopes: oauthScopes
            )
        }

        let user = result.user

        // Verify calendar scope was granted
        guard user.grantedScopes?.contains(where: { oauthScopes.contains($0) }) == true else {
            throw CalendarAuthError.scopeNotGranted
        }

        // Get refresh token
        let refreshToken = user.refreshToken.tokenString

        // Store refresh token and connection status in Firestore
        try await firestore.collection("users").document(userId).updateData([
            "googleCalendarConnected": true,
            "googleCalendarRefreshToken": refreshToken,
            "googleCalendarEmail": user.profile?.email ?? "",
            "googleCalendarConnectedAt": FieldValue.serverTimestamp()
        ])

        print("✅ Google Calendar connected for user: \(userId)")
        return true
    }

    /// Get fresh access token (refreshes if needed)
    /// - Returns: Valid access token
    func getAccessToken() async throws -> String {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw CalendarAuthError.notSignedIn
        }

        // Refresh token if expired
        if let expirationDate = currentUser.accessToken.expirationDate,
           expirationDate < Date() {
            try await currentUser.refreshTokensIfNeeded()
        }

        return currentUser.accessToken.tokenString
    }

    /// Revoke Google Calendar access
    func disconnect() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw CalendarAuthError.notAuthenticated
        }

        // Revoke token with Google
        do {
            try await GIDSignIn.sharedInstance.disconnect()
        } catch {
            print("⚠️ Failed to revoke Google token: \(error.localizedDescription)")
            // Continue anyway to clear local data
        }

        // Clear Firestore data
        try await firestore.collection("users").document(userId).updateData([
            "googleCalendarConnected": false,
            "googleCalendarRefreshToken": FieldValue.delete(),
            "googleCalendarEmail": FieldValue.delete(),
            "googleCalendarConnectedAt": FieldValue.delete()
        ])
    }

    /// Check if user has valid Google Sign-In session
    func hasValidSession() -> Bool {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            return false
        }

        // Check if calendar scopes are granted
        return currentUser.grantedScopes?.contains(where: { oauthScopes.contains($0) }) == true
    }

    /// Restore previous sign-in session on app launch
    func restorePreviousSignIn() async throws {
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            print("✅ Restored previous Google Sign-In: \(user.profile?.email ?? "unknown")")
        } catch {
            print("ℹ️ No previous Google Sign-In to restore: \(error.localizedDescription)")
            // Not an error - user simply hasn't signed in before
        }
    }

    // MARK: - Private Helpers

    /// Get OAuth Client ID from GoogleService-Info.plist
    private func getClientID() -> String? {
        // First, try Info.plist (standard location)
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            return clientID
        }

        // Fallback: Read directly from GoogleService-Info.plist
        // Firebase loads the correct plist based on build configuration (Dev vs Prod)
        // The plist is copied to the bundle during build

        // Try multiple possible locations
        let possibleNames = [
            "GoogleService-Info-Dev",  // Dev configuration
            "GoogleService-Info-Prod", // Prod configuration
            "GoogleService-Info"       // Default name
        ]

        for name in possibleNames {
            if let path = Bundle.main.path(forResource: name, ofType: "plist"),
               let plist = NSDictionary(contentsOfFile: path),
               let clientID = plist["CLIENT_ID"] as? String,
               !clientID.contains("YOUR_") { // Skip placeholder values
                print("✅ Found CLIENT_ID in \(name).plist")
                return clientID
            }
        }

        print("❌ CLIENT_ID not found in any GoogleService-Info plist")
        return nil
    }
}

// MARK: - Error Types

enum CalendarAuthError: LocalizedError {
    case notAuthenticated
    case missingClientID
    case noPresentingViewController
    case scopeNotGranted
    case noRefreshToken
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User must be authenticated with Firebase first"
        case .missingClientID:
            return "OAuth Client ID not found in GoogleService-Info.plist. Please complete Step 3 of setup."
        case .noPresentingViewController:
            return "No view controller available to present sign-in UI"
        case .scopeNotGranted:
            return "Calendar access was not granted. Please allow calendar permissions."
        case .noRefreshToken:
            return "Failed to obtain refresh token from Google"
        case .notSignedIn:
            return "Not signed in with Google. Please connect your calendar first."
        }
    }
}

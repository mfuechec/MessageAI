//
//  UserAvatarView.swift
//  MessageAI
//
//  Unified user avatar component with consistent Kingfisher caching
//  Fixes Issue #2: Wrong image sometimes used for users
//

import SwiftUI
import Kingfisher

/// Unified user avatar component with consistent caching across the app
///
/// Replaces mixed AsyncImage implementations with Kingfisher-based caching.
/// Provides consistent memory + disk caching, preventing wrong user image flashes
/// during rapid scrolling or view recycling.
struct UserAvatarView: View {
    let user: User
    let size: CGFloat
    let showPresenceIndicator: Bool

    /// Initialize user avatar
    /// - Parameters:
    ///   - user: User to display avatar for
    ///   - size: Avatar diameter in points
    ///   - showPresenceIndicator: Whether to show online/offline indicator
    init(user: User, size: CGFloat = 50, showPresenceIndicator: Bool = false) {
        self.user = user
        self.size = size
        self.showPresenceIndicator = showPresenceIndicator
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main avatar image or placeholder
            if let photoURL = user.profileImageURL,
               let url = URL(string: photoURL) {
                KFImage(url)
                    .placeholder {
                        initialsPlaceholder
                    }
                    .cacheOriginalImage()  // Cache both original and downsampled
                    .fade(duration: 0.2)
                    .resizable()
                    .downsampling(size: CGSize(width: size * 2, height: size * 2))  // Retina @2x
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                initialsPlaceholder
            }

            // Presence indicator
            if showPresenceIndicator {
                presenceIndicator
            }
        }
        .id(user.id)  // Force unique identity per user to prevent cache collision
    }

    /// Initials placeholder for users without profile images
    private var initialsPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.3))

            Text(user.displayInitials)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }

    /// Presence indicator with 3 states (online, recently offline, offline)
    private var presenceIndicator: some View {
        let colors = user.presenceStatus.color
        let indicatorColor = Color(
            red: colors.red,
            green: colors.green,
            blue: colors.blue
        )

        return Circle()
            .fill(indicatorColor)
            .frame(width: size * 0.25, height: size * 0.25)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: size * 0.05)
            )
    }
}

// MARK: - Preview

#if DEBUG
struct UserAvatarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // User with image and online
            UserAvatarView(
                user: User(
                    id: "1",
                    email: "john@example.com",
                    displayName: "John Doe",
                    profileImageURL: "https://via.placeholder.com/150",
                    isOnline: true
                ),
                size: 60,
                showPresenceIndicator: true
            )

            // User with initials and offline
            UserAvatarView(
                user: User(
                    id: "2",
                    email: "jane@example.com",
                    displayName: "Jane Smith",
                    isOnline: false
                ),
                size: 60,
                showPresenceIndicator: true
            )

            // Small avatar without presence
            UserAvatarView(
                user: User(
                    id: "3",
                    email: "bob@example.com",
                    displayName: "Bob Wilson"
                ),
                size: 40,
                showPresenceIndicator: false
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

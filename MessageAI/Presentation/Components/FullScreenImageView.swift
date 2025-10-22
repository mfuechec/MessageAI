//
//  FullScreenImageView.swift
//  MessageAI
//
//  Full-screen image viewer with pinch-to-zoom and share
//

import SwiftUI
import Kingfisher

/// Full-screen image viewer with pinch-to-zoom
struct FullScreenImageView: View {
    let imageURL: String
    var onDismiss: () -> Void = {}
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Image with zoom
            KFImage(URL(string: imageURL))
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                            // Reset if zoomed out too far
                            if scale < 1.0 {
                                withAnimation {
                                    scale = 1.0
                                    lastScale = 1.0
                                }
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    // Double-tap to reset zoom
                    withAnimation {
                        scale = 1.0
                        lastScale = 1.0
                    }
                }

            // Overlay controls
            VStack {
                HStack {
                    Spacer()

                    // Close button
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }

                Spacer()

                // Share button
                Button {
                    shareImage(url: imageURL)
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)
                }
                .padding()
            }
        }
    }

    private func shareImage(url: String) {
        guard let url = URL(string: url) else { return }

        // Download image first
        KingfisherManager.shared.retrieveImage(with: url) { result in
            switch result {
            case .success(let imageResult):
                let activityVC = UIActivityViewController(
                    activityItems: [imageResult.image],
                    applicationActivities: nil
                )

                // Present on current window
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }

            case .failure(let error):
                print("❌ Failed to load image for sharing: \(error)")
            }
        }
    }
}

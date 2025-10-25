//
//  QuickLookPreview.swift
//  MessageAI
//
//  SwiftUI wrapper for QLPreviewController to view PDF documents
//

import SwiftUI
import QuickLook

/// SwiftUI wrapper for QLPreviewController to display PDF documents
struct QuickLookPreview: UIViewControllerRepresentable {
    let fileURL: URL
    var onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        context.coordinator.previewController = controller
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let parent: QuickLookPreview
        private var localFileURL: URL?
        weak var previewController: QLPreviewController?

        init(_ parent: QuickLookPreview) {
            self.parent = parent
            super.init()
            downloadFileIfNeeded()
        }

        // MARK: - QLPreviewControllerDataSource

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            let count = localFileURL != nil ? 1 : 0
            print("📄 [QuickLookPreview] numberOfPreviewItems called: \(count)")
            print("   localFileURL: \(localFileURL?.absoluteString ?? "nil")")
            return count
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            print("📄 [QuickLookPreview] previewItemAt \(index) called")
            guard let url = localFileURL else {
                print("   ❌ No local file URL available")
                // Return empty URL if download failed
                return URL(fileURLWithPath: "") as QLPreviewItem
            }
            print("   ✅ Returning URL: \(url.lastPathComponent)")
            return url as QLPreviewItem
        }

        // MARK: - File Download

        private func downloadFileIfNeeded() {
            let url = parent.fileURL
            print("📥 [QuickLookPreview] downloadFileIfNeeded called")
            print("   URL: \(url.absoluteString)")
            print("   isFileURL: \(url.isFileURL)")

            // If it's already a local file, use it directly
            if url.isFileURL {
                print("   ✅ Local file - using directly")
                localFileURL = url
                return
            }

            // If it's a remote URL, download to temp directory
            print("   🌐 Remote URL - starting download...")
            Task {
                do {
                    let (tempURL, _) = try await URLSession.shared.download(from: url)
                    print("   ✅ Download completed to: \(tempURL.path)")

                    // Use UUID for filename to avoid issues with URL query parameters
                    // Extract file extension from URL path (not lastPathComponent which includes query params)
                    let pathExtension = url.pathExtension.isEmpty ? "pdf" : url.pathExtension
                    let fileName = "\(UUID().uuidString).\(pathExtension)"
                    let destination = FileManager.default.temporaryDirectory
                        .appendingPathComponent(fileName)

                    print("   📁 Moving to: \(destination.path)")

                    // Remove existing file if present
                    try? FileManager.default.removeItem(at: destination)

                    // Move downloaded file to permanent temp location
                    try FileManager.default.moveItem(at: tempURL, to: destination)

                    print("   ✅ File ready at: \(destination.path)")

                    await MainActor.run {
                        self.localFileURL = destination
                        print("   🔄 Set localFileURL - reloading QLPreviewController")
                        self.previewController?.reloadData()
                        print("   ✅ QLPreviewController reloaded")
                    }

                } catch {
                    print("❌ Failed to download document: \(error.localizedDescription)")
                    await MainActor.run {
                        self.parent.onDismiss?()
                    }
                }
            }
        }
    }
}

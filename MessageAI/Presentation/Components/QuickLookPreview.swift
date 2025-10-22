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

        init(_ parent: QuickLookPreview) {
            self.parent = parent
            super.init()
            downloadFileIfNeeded()
        }

        // MARK: - QLPreviewControllerDataSource

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return localFileURL != nil ? 1 : 0
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return localFileURL! as QLPreviewItem
        }

        // MARK: - File Download

        private func downloadFileIfNeeded() {
            let url = parent.fileURL

            // If it's already a local file, use it directly
            if url.isFileURL {
                localFileURL = url
                return
            }

            // If it's a remote URL, download to temp directory
            Task {
                do {
                    let (tempURL, _) = try await URLSession.shared.download(from: url)
                    let destination = FileManager.default.temporaryDirectory
                        .appendingPathComponent(url.lastPathComponent)

                    // Remove existing file if present
                    try? FileManager.default.removeItem(at: destination)

                    // Move downloaded file to permanent temp location
                    try FileManager.default.moveItem(at: tempURL, to: destination)

                    await MainActor.run {
                        self.localFileURL = destination
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

//
//  DocumentPickerView.swift
//  MessageAI
//
//  SwiftUI wrapper for UIDocumentPickerViewController
//

import SwiftUI
import UniformTypeIdentifiers

/// SwiftUI wrapper for UIDocumentPickerViewController to select PDF documents
struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var selectedDocumentURL: URL?
    var onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.selectedDocumentURL = url
            parent.onDismiss?()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onDismiss?()
        }
    }
}

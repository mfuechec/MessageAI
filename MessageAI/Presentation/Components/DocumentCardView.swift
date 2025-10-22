//
//  DocumentCardView.swift
//  MessageAI
//
//  Displays a document attachment card with file info and upload progress
//

import SwiftUI

/// Displays a document card with file icon, name, size, and optional upload progress
struct DocumentCardView: View {
    let fileName: String
    let fileSizeBytes: Int64
    let uploadProgress: Double?
    let hasError: Bool
    let onTap: () -> Void
    let onRetry: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // File icon
                Image(systemName: "doc.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)

                // File info
                VStack(alignment: .leading, spacing: 4) {
                    Text(fileName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(formattedFileSize)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    // Upload progress or error
                    if let progress = uploadProgress {
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(height: 4)
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else if hasError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text("Tap to retry")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.red)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var formattedFileSize: String {
        DocumentValidator.formatFileSize(fileSizeBytes)
    }
}

// MARK: - Previews

struct DocumentCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Normal state
            DocumentCardView(
                fileName: "Invoice.pdf",
                fileSizeBytes: 2_500_000,
                uploadProgress: nil,
                hasError: false,
                onTap: {},
                onRetry: nil
            )

            // Uploading state
            DocumentCardView(
                fileName: "Project_Proposal_Final_v2.pdf",
                fileSizeBytes: 8_500_000,
                uploadProgress: 0.65,
                hasError: false,
                onTap: {},
                onRetry: nil
            )

            // Error state
            DocumentCardView(
                fileName: "Contract.pdf",
                fileSizeBytes: 1_200_000,
                uploadProgress: nil,
                hasError: true,
                onTap: {},
                onRetry: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

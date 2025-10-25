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
    let isSummaryGenerating: Bool
    let hasSummary: Bool
    let onTap: () -> Void
    let onRetry: (() -> Void)?
    let onSummarize: (() -> Void)?

    private var isPdfReady: Bool {
        uploadProgress == nil && !hasError
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main document card
            Button(action: isPdfReady ? onTap : {}) {
                HStack(spacing: 12) {
                    // File icon
                    Image(systemName: "doc.fill")
                        .font(.system(size: 40))
                        .foregroundColor(isPdfReady ? .blue : .gray)

                    // File info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fileName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(isPdfReady ? .primary : .secondary)
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
            }
            .buttonStyle(.plain)

            // Summarize button - always show if not in error state
            if !hasError, let summarizeAction = onSummarize {
                Divider()

                Button(action: (isPdfReady && hasSummary) ? summarizeAction : {}) {
                    HStack(spacing: 6) {
                        if isSummaryGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                        }

                        if isSummaryGenerating {
                            Text("Generating Summary...")
                                .font(.system(size: 14, weight: .medium))
                        } else {
                            Text("Summarize PDF")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .foregroundColor((isPdfReady && hasSummary) ? .blue : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .disabled(!isPdfReady || !hasSummary)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var formattedFileSize: String {
        DocumentValidator.formatFileSize(fileSizeBytes)
    }
}

// MARK: - Previews

struct DocumentCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Normal state with summarize button
            DocumentCardView(
                fileName: "Invoice.pdf",
                fileSizeBytes: 2_500_000,
                uploadProgress: nil,
                hasError: false,
                isSummaryGenerating: false,
                hasSummary: true,
                onTap: {},
                onRetry: nil,
                onSummarize: {}
            )

            // Uploading state (no summarize button while uploading)
            DocumentCardView(
                fileName: "Project_Proposal_Final_v2.pdf",
                fileSizeBytes: 8_500_000,
                uploadProgress: 0.65,
                hasError: false,
                isSummaryGenerating: false,
                hasSummary: false,
                onTap: {},
                onRetry: nil,
                onSummarize: nil
            )

            // Error state (no summarize button on error)
            DocumentCardView(
                fileName: "Contract.pdf",
                fileSizeBytes: 1_200_000,
                uploadProgress: nil,
                hasError: true,
                isSummaryGenerating: false,
                hasSummary: false,
                onTap: {},
                onRetry: {},
                onSummarize: nil
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

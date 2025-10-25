//
//  PDFTextExtractor.swift
//  MessageAI
//
//  Service to extract text content from PDF files
//

import Foundation
import PDFKit

/// Service for extracting text from PDF documents
class PDFTextExtractor {

    /// Extract all text from a PDF file
    ///
    /// - Parameter url: URL to the PDF file (local or remote)
    /// - Returns: Extracted text content
    /// - Throws: Error if PDF cannot be loaded or text extraction fails
    static func extractText(from url: URL) async throws -> String {
        print("📄 [PDFTextExtractor] Extracting text from PDF")
        print("   URL: \(url.absoluteString)")

        // Download if remote URL
        let localURL: URL
        if url.isFileURL {
            localURL = url
        } else {
            print("   🌐 Downloading remote PDF...")
            let (downloadedURL, _) = try await URLSession.shared.download(from: url)
            localURL = downloadedURL
            print("   ✅ Downloaded to: \(localURL.path)")
        }

        // Load PDF document
        guard let pdfDocument = PDFDocument(url: localURL) else {
            print("   ❌ Failed to load PDF document")
            throw PDFExtractionError.invalidPDF
        }

        print("   📖 PDF loaded: \(pdfDocument.pageCount) pages")

        // Extract text from all pages
        var fullText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else {
                continue
            }

            if let pageText = page.string {
                fullText += pageText
                fullText += "\n\n" // Add spacing between pages
            }
        }

        let characterCount = fullText.count
        print("   ✅ Extracted \(characterCount) characters from \(pdfDocument.pageCount) pages")

        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("   ❌ No text content found in PDF")
            throw PDFExtractionError.noTextContent
        }

        return fullText
    }
}

/// Errors that can occur during PDF text extraction
enum PDFExtractionError: LocalizedError {
    case invalidPDF
    case noTextContent
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "Unable to load PDF document"
        case .noTextContent:
            return "PDF contains no extractable text (might be image-based)"
        case .downloadFailed:
            return "Failed to download PDF"
        }
    }
}

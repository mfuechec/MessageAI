import Foundation

/// Represents a file attachment in a message (image, video, or file)
struct MessageAttachment: Codable, Equatable {
    let id: String
    let type: AttachmentType
    let url: String
    let thumbnailURL: String?
    let sizeBytes: Int64
    let fileName: String?  // Required for documents (e.g., "Invoice.pdf"), optional for images

    enum AttachmentType: String, Codable {
        case image
        case video  // Future
        case file   // PDF documents
    }
}


# Document Attachment Pattern (Story 2.8)

## Context
Story 2.8 successfully implemented PDF document attachments by reusing 90% of Story 2.7's image attachment infrastructure.

## Key Implementation Pattern

### 1. Entity Extension (Domain Layer)
```swift
struct MessageAttachment: Codable, Equatable {
    let id: String
    let type: AttachmentType
    let url: String
    let thumbnailURL: String?
    let sizeBytes: Int64
    let fileName: String?  // ✅ Added for documents

    enum AttachmentType: String, Codable {
        case image
        case file   // ✅ PDF documents
        case video  // Future
    }
}
```

**Lesson:** Add optional fields to support multiple attachment types without breaking existing functionality.

### 2. Repository Protocol Extension
```swift
protocol StorageRepositoryProtocol {
    func uploadMessageImage(...) async throws -> MessageAttachment
    func uploadMessageDocument(...) async throws -> MessageAttachment  // ✅ Parallel method
    func cancelUpload(for messageId: String) async throws  // ✅ Reused for both
}
```

**Lesson:** Create parallel upload methods for each type, but share common infrastructure (progress tracking, cancellation, error handling).

### 3. Validation Utility Pattern
```swift
struct DocumentValidator {
    static let maxFileSizeBytes: Int64 = 10 * 1024 * 1024  // 10MB

    static func validate(fileURL: URL) throws -> (fileName: String, sizeBytes: Int64) {
        // 1. Security-scoped resource access
        // 2. File size validation
        // 3. MIME type validation (.pdf)
        // 4. Return metadata for UI
    }
}
```

**Lesson:** Create type-specific validators that run BEFORE upload starts. Fail fast on client side.

### 4. ViewModel State Management
```swift
@MainActor
class ChatViewModel: ObservableObject {
    // ✅ Reused from images
    @Published var uploadProgress: [String: Double] = [:]
    @Published var uploadErrors: [String: String] = [:]

    // ✅ New state for documents
    @Published var isDocumentPickerPresented: Bool = false
    @Published var selectedDocumentURL: URL?
    @Published var showDocumentPreview: Bool = false
    @Published var documentPreviewURL: URL?
}
```

**Lesson:** Reuse upload state dictionaries (progress, errors) across all attachment types. Only add type-specific picker/preview state.

### 5. MessageKit Custom Cell Pattern

**Key Discovery:** MessageKit `.custom` kind requires manual cell configuration.

```swift
// In MessageKitMessage.swift
case .file:
    let documentItem = DocumentMediaItem(
        url: attachment.url,
        fileName: attachment.fileName ?? "Document.pdf",
        sizeBytes: attachment.sizeBytes
    )
    self.kind = .custom(documentItem)

// In ChatView Coordinator
func configureCustomCell(_ cell: UICollectionViewCell, ...) {
    // 1. Extract DocumentMediaItem from .custom kind
    // 2. Create SwiftUI DocumentCardView
    // 3. Embed via UIHostingController
    // 4. Wire up tap handlers (retry or QuickLook)
}
```

**Lesson:**
- Use `.custom` MessageKit kind for non-standard media
- Embed SwiftUI components via UIHostingController for best UI/UX
- Handle upload progress and error states in custom cell

### 6. UIMenu Pattern (iOS 14+)

**Attachment Button with Menu:**
```swift
let attachmentButton = InputBarButtonItem()
let photoAction = UIAction(title: "Photo", image: UIImage(systemName: "photo")) { ... }
let documentAction = UIAction(title: "Document", image: UIImage(systemName: "doc")) { ... }
let menu = UIMenu(title: "", children: [photoAction, documentAction])
attachmentButton.menu = menu
attachmentButton.showsMenuAsPrimaryAction = true
```

**Lesson:** Use UIMenu for attachment type selection - cleaner UX than multiple buttons.

### 7. QuickLook Integration

**Pattern:**
```swift
// SwiftUI wrapper for QLPreviewController
struct QuickLookPreview: UIViewControllerRepresentable {
    let fileURL: URL
    var onDismiss: (() -> Void)?

    class Coordinator: QLPreviewControllerDataSource {
        // Download remote file to temp directory if needed
        // Return local file URL for preview
    }
}
```

**Critical:** QuickLook requires local file URL. Download remote Firebase Storage URLs to temp directory first.

### 8. Temporary File Management

**Document Upload:**
```swift
func copyDocumentToTemp(fileURL: URL, messageId: String) throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let tempURL = tempDir.appendingPathComponent("\(messageId).pdf")

    // Access security-scoped resource
    let accessed = fileURL.startAccessingSecurityScopedResource()
    defer { if accessed { fileURL.stopAccessingSecurityScopedResource() } }

    try FileManager.default.copyItem(at: fileURL, to: tempURL)
    return tempURL
}
```

**Lesson:** Copy document picker files to temp directory immediately. Enables retry without re-picking file.

## Firebase Storage Rules Pattern

```
match /documents/{conversationId}/{messageId}/{filename} {
  allow write: if isAuthenticated()
    && isParticipant(conversationId)
    && request.resource.size < 10 * 1024 * 1024;  // 10MB limit

  allow read: if isAuthenticated() && isParticipant(conversationId);
}
```

**Lesson:** Enforce size limits server-side AND client-side for best UX.

## Reusability Metrics

**Story 2.8 Reused from Story 2.7:**
- ✅ Upload progress tracking (uploadProgress dict)
- ✅ Error handling (uploadErrors dict)
- ✅ Offline queue pattern (UserDefaults metadata)
- ✅ Repository cancellation (cancelUpload method)
- ✅ Optimistic UI pattern (message appears immediately)
- ✅ MockStorageRepository pattern

**Story 2.8 New Code:**
- DocumentValidator utility (~100 LOC)
- DocumentPickerView wrapper (~50 LOC)
- DocumentCardView component (~120 LOC)
- QuickLookPreview wrapper (~90 LOC)
- Repository implementation (~80 LOC)

**Reuse Rate: ~90%** ✅

## Testing Strategy

1. **Unit Tests:** Validator logic, upload flow, error handling
2. **Integration Tests:** Deferred to emulator setup (requires local file)
3. **Manual Testing:** End-to-end flow, QuickLook preview, upload performance

**Coverage Achieved:** 18 tests, all passing

## Future Extensions

This pattern supports:
- Video attachments (`.video` type) - reuse same infrastructure
- Multiple attachments per message - extend attachments array
- Other document types (.docx, .xlsx) - extend validator

## Common Pitfalls Avoided

1. ❌ Don't forget `fileName` field for documents (needed for display)
2. ❌ Don't use client-side timestamps (use FieldValue.serverTimestamp())
3. ❌ Don't skip security-scoped resource access for document picker files
4. ❌ Don't forget to download remote URLs before showing in QuickLook
5. ❌ Don't hardcode file paths - use temp directory + messageId

## Related Stories
- Story 2.7: Image Attachments (foundation)
- Future: Video Attachments (will reuse this pattern)

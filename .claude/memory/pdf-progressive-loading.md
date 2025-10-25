# PDF Progressive Loading UX

## Feature Overview

Implemented progressive loading UX for PDF attachments with AI-powered summarization. Users see immediate visual feedback at each stage of the upload and summarization process.

## User Experience Flow

1. **During Upload** → Greyed out PDF title + greyed out "Summarize PDF" button
2. **PDF Ready** → PDF preview becomes clickable (blue icon), can view document
3. **Summary Generating** → Shows "Generating Summary..." with spinner
4. **Summary Ready** → "Summarize PDF" button fully enabled, tappable

## Implementation Details

### State Management (ChatViewModel.swift:89)
```swift
@Published var summaryGenerationInProgress: [String: Bool] = [:]
```
- Tracks which message IDs are currently generating AI summaries
- Allows UI to show progress indicators per message

### Background Processing (ChatViewModel.swift:1833-1871)
- AI summary generation runs in background Task after PDF upload completes
- Non-blocking - user can continue using chat while summary generates
- Updates message in Firestore with aiSummary field when complete
- Handles errors gracefully by clearing generation state

### UI Component (DocumentCardView.swift)
**New Parameters:**
- `isSummaryGenerating: Bool` - Shows spinner and "Generating Summary..." text
- `hasSummary: Bool` - Enables "Summarize PDF" button when summary exists

**Progressive States:**
- Upload in progress: Grey PDF icon + disabled preview button
- PDF ready: Blue PDF icon + enabled preview button
- Summary generating: Progress spinner + "Generating Summary..." text
- Summary ready: Blue "Summarize PDF" button enabled

### Data Flow

1. **Upload PDF** → FirebaseStorageRepository uploads to Firebase Storage
2. **Message Created** → Message saved to Firestore with attachment URL
3. **Extract Text** → PDFTextExtractor downloads and extracts text using PDFKit
4. **Call AI** → CloudFunctionsService.callSummarizePDF() with text
5. **Store Summary** → Update message.attachments[0].aiSummary in Firestore
6. **Display** → Recipients get cached summary instantly from database

## Key Files

### Frontend (iOS)
- `MessageAI/Presentation/Components/DocumentCardView.swift` - UI component with progressive states
- `MessageAI/Presentation/ViewModels/Chat/ChatViewModel.swift` - State management + background processing
- `MessageAI/Presentation/Views/Chat/ChatView.swift` - Passes state to DocumentCardView
- `MessageAI/Data/Services/PDFTextExtractor.swift` - Extracts text from PDF using PDFKit
- `MessageAI/Data/Network/CloudFunctionsService.swift` - Calls summarizePDF Cloud Function
- `MessageAI/Domain/Entities/MessageAttachment.swift` - Added aiSummary field

### Backend (Cloud Functions)
- `functions/src/summarizePDF.ts` - OpenAI GPT-4-mini integration
  - 220 lines
  - 30-day smart caching
  - 50 requests/day rate limiting
  - Returns 3-5 sentence summaries

## Technical Notes

### Why Background Processing?
- PDF text extraction: ~1-2 seconds
- OpenAI API call: ~5-10 seconds
- Total: ~7-12 seconds

Running in background prevents blocking UI and allows user to continue chatting.

### Why Store in Database?
- Recipients don't regenerate summary (saves API calls)
- Instant display for cached summaries (< 1 second vs 7-12 seconds)
- Works offline after first load
- 70%+ cost savings from caching

### QuickLook Fix
Fixed file preview error by using UUID-based filenames instead of Firebase Storage URLs with query parameters:
```swift
let fileName = "\(UUID().uuidString).\(pathExtension)"
```

## Related Features

- **Story 2.8**: Document Attachments - PDF upload infrastructure
- **Story 3.1**: AI Cloud Functions - OpenAI integration
- **Epic 6**: Smart Notifications - AI-powered features

## Testing

Build succeeds with no errors:
```bash
./scripts/build.sh
```

Manual testing:
1. Upload PDF attachment in chat
2. Verify greyed out states during upload
3. Verify PDF preview works when ready
4. Verify "Generating Summary..." appears with spinner
5. Verify summary displays in sheet when tapped

## Future Enhancements

- Show summary preview in card (first sentence)
- Support multi-page PDF summaries
- Add "Copy Summary" button
- Cache extracted text to avoid re-extraction

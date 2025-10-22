# Technical Debt & Future Improvements

This file tracks improvement opportunities identified during QA reviews that are not blocking but should be considered for future sprints.

---

## Story 2.7: Image Attachments

**Source:** QA Review (2025-10-22)
**Priority:** Low
**Status:** Backlog

### Improvements

#### 1. Structured Logging Framework
- **Current State:** Using `print()` statements throughout codebase for diagnostics
- **Recommendation:** Adopt OSLog or unified logging framework for production
- **Impact:** Better production debugging, log level filtering, performance monitoring
- **Effort:** Medium
- **Files Affected:** Multiple files (ImageCompressor, ImageCacheManager, FirebaseStorageRepository, ChatViewModel)
- **Suggested Sprint:** Post-MVP (Epic 3+)

#### 2. Error Handling Improvements in ImageCacheManager
- **Current State:** Using `try?` which silently swallows errors
- **Recommendation:** Replace with proper error logging or Result type
- **Impact:** Better error visibility and diagnostics
- **Effort:** Low
- **Files Affected:**
  - `MessageAI/Presentation/Utils/ImageCacheManager.swift` (lines 43, 50)
- **Code Examples:**
  ```swift
  // Current (line 43):
  return try? Data(contentsOf: fileURL)

  // Recommended:
  do {
      return try Data(contentsOf: fileURL)
  } catch {
      print("⚠️ [ImageCache] Failed to load image: \(error.localizedDescription)")
      return nil
  }
  ```
- **Suggested Sprint:** Post-MVP (Epic 3+)

#### 3. Configuration Extraction
- **Current State:** Magic numbers used for compression quality and dimensions
- **Recommendation:** Extract to named constants or configuration struct
- **Impact:** Improved maintainability, easier to tune compression settings
- **Effort:** Low
- **Files Affected:**
  - `MessageAI/Presentation/Utils/ImageCompressor.swift` (lines 22-26, 46)
- **Code Example:**
  ```swift
  // Recommended:
  enum ImageCompressionConfig {
      static let maxSizeBytes: Int64 = 2 * 1024 * 1024
      static let initialQuality: CGFloat = 0.8
      static let minimumQuality: CGFloat = 0.1
      static let qualityDecrement: CGFloat = 0.1
      static let maxDimension: CGFloat = 1920
  }
  ```
- **Suggested Sprint:** Next refactoring sprint (Epic 2.x or 3.1)

#### 4. Analytics Logging
- **Current State:** No analytics tracking for upload failures/success
- **Recommendation:** Add analytics events for upload lifecycle
- **Impact:** Better production monitoring, identify user pain points
- **Effort:** Low
- **Metrics to Track:**
  - Image upload success rate
  - Average upload duration
  - Compression time
  - Retry success rate
  - Offline queue usage
  - Upload cancellation rate
- **Suggested Sprint:** Analytics Epic (future)

---

## Guidelines

- **Priority Levels:**
  - **Critical:** Security vulnerabilities, data loss risks
  - **High:** Performance bottlenecks, user-facing bugs
  - **Medium:** Code quality issues affecting maintainability
  - **Low:** Nice-to-have improvements, refactoring opportunities

- **Effort Estimates:**
  - **Low:** < 4 hours
  - **Medium:** 4-16 hours (0.5-2 days)
  - **High:** > 16 hours (> 2 days)

- **Review Cycle:**
  - Review this file quarterly or before planning new epics
  - Tag items with story numbers for traceability
  - Archive completed items to separate file

---

**Last Updated:** 2025-10-22 by Quinn (Test Architect)

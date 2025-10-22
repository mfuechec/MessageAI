//
//  DocumentValidatorTests.swift
//  MessageAITests
//
//  Tests for DocumentValidator utility
//

import XCTest
@testable import MessageAI

@MainActor
final class DocumentValidatorTests: XCTestCase {

    // MARK: - Test File Creation Helpers

    /// Create a temporary PDF file for testing
    private func createTempPDF(sizeMB: Int, fileName: String = "test.pdf") -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        // Create PDF data of specified size
        let sizeBytes = sizeMB * 1024 * 1024
        let data = Data(repeating: 0, count: sizeBytes)

        try? FileManager.default.removeItem(at: fileURL)
        try? data.write(to: fileURL)

        return fileURL
    }

    /// Create a temporary non-PDF file for testing
    private func createTempNonPDF(sizeMB: Int) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test.txt")

        let sizeBytes = sizeMB * 1024 * 1024
        let data = Data(repeating: 0, count: sizeBytes)

        try? FileManager.default.removeItem(at: fileURL)
        try? data.write(to: fileURL)

        return fileURL
    }

    override func tearDown() async throws {
        // Clean up temp files
        let tempDir = FileManager.default.temporaryDirectory
        try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("test.pdf"))
        try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("test.txt"))
        try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("Invoice.pdf"))

        try await super.tearDown()
    }

    // MARK: - Tests

    func testValidate_ValidPDF_Success() throws {
        // Given: A valid PDF under 10MB
        let fileURL = createTempPDF(sizeMB: 5, fileName: "Invoice.pdf")

        // When: Validating the file
        let result = try DocumentValidator.validate(fileURL: fileURL)

        // Then: Validation succeeds and returns correct metadata
        XCTAssertEqual(result.fileName, "Invoice.pdf")
        XCTAssertEqual(result.sizeBytes, 5 * 1024 * 1024)
    }

    func testValidate_FileTooLarge_ThrowsError() {
        // Given: A PDF larger than 10MB
        let fileURL = createTempPDF(sizeMB: 11)

        // When/Then: Validation throws fileTooLarge error
        XCTAssertThrowsError(try DocumentValidator.validate(fileURL: fileURL)) { error in
            guard case DocumentValidationError.fileTooLarge(let maxSize) = error else {
                XCTFail("Expected fileTooLarge error")
                return
            }
            XCTAssertEqual(maxSize, 10)
        }
    }

    func testValidate_NonPDFFile_ThrowsError() {
        // Given: A non-PDF file
        let fileURL = createTempNonPDF(sizeMB: 1)

        // When/Then: Validation throws unsupportedFileType error
        XCTAssertThrowsError(try DocumentValidator.validate(fileURL: fileURL)) { error in
            guard case DocumentValidationError.unsupportedFileType = error else {
                XCTFail("Expected unsupportedFileType error")
                return
            }
        }
    }

    func testValidate_SmallPDF_Success() throws {
        // Given: A very small PDF (100KB)
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("small.pdf")

        let data = Data(repeating: 0, count: 100 * 1024)  // 100KB
        try data.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        // When: Validating the file
        let result = try DocumentValidator.validate(fileURL: fileURL)

        // Then: Validation succeeds
        XCTAssertEqual(result.fileName, "small.pdf")
        XCTAssertEqual(result.sizeBytes, 100 * 1024)
    }

    func testValidate_ExactlyAtLimit_Success() throws {
        // Given: A PDF exactly at 10MB limit
        let fileURL = createTempPDF(sizeMB: 10)

        // When: Validating the file
        let result = try DocumentValidator.validate(fileURL: fileURL)

        // Then: Validation succeeds (10MB is acceptable)
        XCTAssertEqual(result.sizeBytes, 10 * 1024 * 1024)
    }

    func testFormatFileSize_Bytes() {
        // Given: File size in bytes
        let size: Int64 = 512

        // When: Formatting the size
        let formatted = DocumentValidator.formatFileSize(size)

        // Then: Returns formatted string with KB
        XCTAssertTrue(formatted.contains("KB") || formatted.contains("bytes"))
    }

    func testFormatFileSize_Kilobytes() {
        // Given: File size in KB range
        let size: Int64 = 500 * 1024  // 500KB

        // When: Formatting the size
        let formatted = DocumentValidator.formatFileSize(size)

        // Then: Returns formatted string with KB
        XCTAssertTrue(formatted.contains("KB"))
    }

    func testFormatFileSize_Megabytes() {
        // Given: File size in MB range
        let size: Int64 = 5 * 1024 * 1024  // 5MB

        // When: Formatting the size
        let formatted = DocumentValidator.formatFileSize(size)

        // Then: Returns formatted string with MB
        XCTAssertTrue(formatted.contains("MB"))
    }

    func testValidate_ExtractsCorrectFileName() throws {
        // Given: A PDF with specific name
        let fileURL = createTempPDF(sizeMB: 1, fileName: "Project_Report_Final.pdf")

        // When: Validating the file
        let result = try DocumentValidator.validate(fileURL: fileURL)

        // Then: Extracts correct file name
        XCTAssertEqual(result.fileName, "Project_Report_Final.pdf")

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }
}

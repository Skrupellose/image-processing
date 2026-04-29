import Foundation
import XCTest
@testable import LiveCoverStudio

final class LivePhotoPreviewResourceServiceTests: XCTestCase {
    func testCleanupDirectoryRemovesExistingFiles() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let first = root.appendingPathComponent("old-1.jpg")
        let second = root.appendingPathComponent("old-2.jpg")
        fileManager.createFile(atPath: first.path, contents: Data())
        fileManager.createFile(atPath: second.path, contents: Data())

        let service = LivePhotoPreviewResourceService()
        try service.cleanupDirectory(root)

        let remaining = try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        XCTAssertTrue(remaining.isEmpty)
    }
}

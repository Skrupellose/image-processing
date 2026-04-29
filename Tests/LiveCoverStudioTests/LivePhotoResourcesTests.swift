import Foundation
import XCTest
@testable import LiveCoverStudio

final class LivePhotoResourcesTests: XCTestCase {
    func testPrefersStillImageNameForDisplayName() {
        let resources = LivePhotoResources(
            stillImageURL: URL(fileURLWithPath: "/tmp/cover.heic"),
            motionVideoURL: URL(fileURLWithPath: "/tmp/motion.mov")
        )

        XCTAssertEqual(resources.displayName, "cover")
    }

    func testFallsBackToVideoNameWhenStillImageIsMissing() {
        let resources = LivePhotoResources(
            stillImageURL: nil,
            motionVideoURL: URL(fileURLWithPath: "/tmp/motion.mov")
        )

        XCTAssertEqual(resources.displayName, "motion")
    }

    func testReturnsPlaceholderWhenNoResourcesExist() {
        XCTAssertEqual(LivePhotoResources().displayName, "未选择资源")
    }
}

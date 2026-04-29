import XCTest
@testable import LiveCoverStudio

final class StringFileNameTests: XCTestCase {
    func testReplacesInvalidCharacters() {
        XCTAssertEqual("a/b:c*name".sanitizedFileName(defaultName: "fallback"), "a-b-c-name")
    }

    func testFallsBackWhenSanitizedNameIsEmpty() {
        XCTAssertEqual("\n\r".sanitizedFileName(defaultName: "fallback"), "fallback")
    }
}

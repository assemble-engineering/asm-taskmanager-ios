import XCTest
@testable import EventManager

final class EventManagerTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(EventManager().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}

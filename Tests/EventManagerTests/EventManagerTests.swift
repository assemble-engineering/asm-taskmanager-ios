import XCTest
@testable import EventManager

final class EventManagerTests: XCTestCase {
    func testManagement() {
		EventManager.shared.use(eventRunner: TestEventRunner())
		let testContext = TestEventContext()
		let eventRecord = EventManager.EventRecord(context: testContext.encode())

		EventManager.shared.manage(eventRecord: eventRecord)
		XCTAssert(true)
    }

    static var allTests = [
        ("testManagement", testManagement),
    ]
}

struct TestEventContext: Codable {
	var testDescription = "TEST CONTEXT"
	func encode() -> String {
		let data = try! JSONEncoder().encode(self)
		return String(data: data, encoding: .utf8)!
	}

}

struct TestEventRunner: EventRunner {
	func run(_ eventRecord: EventManager.EventRecord, completion: @escaping (EventManager.EventRecord) -> Void) {
		print("running event \(eventRecord)")
		completion(eventRecord)
	}
	
}

import XCTest
@testable import TaskManager

final class TaskManagerTests: XCTestCase {
    func testManagement() {
		TaskManager.shared.use(taskRunner: TestTaskRunner())
		let testContext = TestTaskContext()
		let taskRecord = TaskManager.TaskRecord(context: testContext.encode())

		TaskManager.shared.manage(taskRecord: taskRecord)
		XCTAssert(true)
    }

    static var allTests = [
        ("testManagement", testManagement),
    ]
}

struct TestTaskContext: Codable {
	var testDescription = "TEST CONTEXT"
	func encode() -> String {
		let data = try! JSONEncoder().encode(self)
		return String(data: data, encoding: .utf8)!
	}

}

struct TestTaskRunner: TaskRunner {
	func run(_ taskRecord: TaskManager.TaskRecord, completion: @escaping (TaskManager.TaskRecord) -> Void) {
		print("running task \(taskRecord)")
		completion(taskRecord)
	}
	
}

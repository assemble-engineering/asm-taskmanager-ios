import XCTest
@testable import TaskManager

final class TaskManagerTests: XCTestCase {
    func testManagement() {
		TaskManager.shared.taskStore.clear()

		TaskManager.shared.use(taskRunner: TestTaskRunner())
		let customAction = TestAction()
		let context = customAction.encode()
		let task = TaskManager.Task(context: context)
//		let c2 = TestAction.decode(from: context)
		
		TaskManager.shared.manage(task: task)
		TaskManager.shared.manage(task: task)
		// Size of managment queue should only be 1 (no duplicates)
		XCTAssertEqual(TaskManager.shared.taskStore.taskIndex.count, 1)
		
//		TaskManager.shared.manage(task: TaskManager.Task(context: "here's my custom context"))
		
		TaskManager.shared.executeTasks { (result) in
			print("Finished tasks with result: \(result)")
		}
//		TaskManager.shared.taskStore.clear()
//		XCTAssertEqual(TaskManager.shared.taskStore.taskIndex.count, 0)

    }

    static var allTests = [
        ("testManagement", testManagement),
    ]
}

struct TestAction: Codable {
	var testDescription = "TEST CONTEXT"
	func encode() -> Data {
		return try! JSONEncoder().encode(self)
	}
	
	static func decode(from data: Data) -> TestAction{
		let action = try! JSONDecoder().decode(TestAction.self, from: data)
		return action
	}
}

struct TestTaskRunner: TaskRunner {
	func run(task: TaskManager.Task, completion: @escaping (Result<Bool, Error>) -> Void) {
		print("TestTaskRunner running task \(task)")
		let testAction = TestAction.decode(from: task.context)
		print("Inner action = \(testAction.testDescription)")
		completion(.success(true))
	}
	
}

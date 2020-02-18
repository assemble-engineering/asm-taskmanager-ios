import XCTest
@testable import TaskManager

final class TaskManagerTests: XCTestCase {
    func testManagement() {
//		TaskManager.shared.clearStore()

		TaskManager.shared.register(taskRunner: TestTaskRunner(), taskType: "TestActionType")
		let customAction = TestAction()
		let task = TaskManager.Task(context: customAction, taskType: "TestActionType")
//		let c2 = TestAction.decode(from: context)
		
		TaskManager.shared.manage(task: task)
		TaskManager.shared.manage(task: task)
		// Size of managment queue should only be 1 (no duplicates)
//		XCTAssertEqual(TaskManager.shared.taskStore.taskIndex.count, 1)
		
//		TaskManager.shared.manage(task: TaskManager.Task(context: "here's my custom context"))
		
		TaskManager.shared.executeTasks { (result) in
			print("Finished tasks with result: \(result)")
			XCTAssertEqual(TaskManager.shared.taskStore.taskIndex.count, 0)


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
}

struct TestTaskRunner: TaskRunner {
	func run(task: TaskManager.Task, completion: @escaping (Result<Bool, Error>) -> Void) {
		print("TestTaskRunner running task \(task)")
		let testAction = task.context(as: TestAction.self)
		print("Inner action = \(testAction.testDescription)")
		completion(.success(true))
	}
	
}

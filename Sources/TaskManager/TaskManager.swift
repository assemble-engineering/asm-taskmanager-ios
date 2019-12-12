import Foundation

class TaskManager {
	static let shared = TaskManager()
	let taskStore = TaskStore()
	var taskRunner: TaskRunner?
	var executingTasks = false
	
	enum TaskManagerError: Error {
		case missingTaskRunner
		case busyExecutingTasks
	}
	
	func use(taskRunner: TaskRunner){
		self.taskRunner = taskRunner
	}
	
	func manage(task: Task){
		self.taskStore.store(task)
	}
	
	func executeTasks(completion: @escaping (Result<Bool, Error>) -> Void){
		
		guard let taskRunner = self.taskRunner else {
			completion(.failure(TaskManagerError.missingTaskRunner))
			return
		}
		
		if executingTasks {
			completion(.failure(TaskManagerError.busyExecutingTasks))
			return
		}
		
		executingTasks = true
		let group = DispatchGroup()
		let queue = DispatchQueue.global()
		
		taskStore.taskIndex.forEach { (key, task) in
			group.enter()
			queue.async(group: group) {
				taskRunner.run(task: task){ result in
					switch result {
						case .success(_):
							self.taskStore.remove(task) //because it should be done
						case .failure(let error):
							print ("Error: \(error)")
					}
					completion(result)
					group.leave()
				}
			}
		}
		
		let _ = group.wait(timeout: .now() + 10.0)
		
		group.notify(queue: queue){
			queue.async {
				self.executingTasks = false
				completion(.success(true))
			}
		}

	}
	

	// An task is an object that has an identifier and created date
	struct Task: Codable {
		var identifier: String
		var createdAt: Date
		var context: Data
		
		init(context: Data){
			identifier = UUID().uuidString
			createdAt = Date()
			self.context = context
		}

		func encode () -> String {
			let encoder = JSONEncoder()
			let data = try! encoder.encode(self)
			return String(data: data, encoding: .utf8)!
		}
	}

	typealias TaskIndex = [String: Task]

	class TaskStore {
		var taskIndex = TaskIndex()

		let cacheBaseDir = "com.asm.ASMContextManager/TaskStore/Tasks"
		let cacheFilePath = "com.asm.ASMContextManager/TaskStore/TaskIndex.json"

		init() {
			self.loadIndex()
		}
		  
		var baseUrl: URL {
			get {
				let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
				return url!.appendingPathComponent("\(cacheBaseDir)")
			}
		}
		
		func cachePath() -> String? {
			var cachePath: String? = nil
			
			if let docsBaseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
				cachePath = docsBaseURL.appendingPathComponent(self.cacheFilePath).path
			}
			
			return cachePath
		}
		
		
		func url(forTask task: Task) -> URL {
			return self.baseUrl.appendingPathComponent(task.identifier + ".task")
		}
		
		func store(_ task: Task){
			if self.taskIndex[task.identifier] != nil {
				print("Task already exists, not allowing duplicate")
				return
			}

			let fileUrl = self.url(forTask: task)
				
			do {
				let fileBaseUrl = fileUrl.deletingLastPathComponent()
				try FileManager.default.createDirectory(at: fileBaseUrl, withIntermediateDirectories: true, attributes: nil)
				let contentString = task.encode()
				try contentString.write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
				
				print("TaskStore saved \(task) to file \n\(fileUrl)")
				self.taskIndex[task.identifier] = task
				self.saveIndex()
			} catch {
				// failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
				print("Failed to write")
			}
		}
		
		func remove(_ task: Task){
			let fileUrl = self.url(forTask: task)
			print("Removing \(fileUrl)")
			self.taskIndex.removeValue(forKey: task.identifier)
			try! FileManager.default.removeItem(at: fileUrl)
		}
		
		func loadIndex() {
			do {
				if let cachePath = cachePath() {
					let url = URL(fileURLWithPath: cachePath)
					let d = try Data(contentsOf:url)
					
					let decoder = JSONDecoder()
					self.taskIndex = try decoder.decode(TaskIndex.self, from: d)
				}
				else {
					print("Failed to unarchive task index")
				}
			} catch {
				print("Failed to decode task index")
			}
		}
		
		func saveIndex(){
			do {
				if let cachePath = cachePath() {
					let url = URL(fileURLWithPath: cachePath)
					
					let encoder = JSONEncoder()
					let d = try encoder.encode(self.taskIndex)
					try d.write(to: url)
					print("Saved cache index \(url)")
				} else {
					print("Failed to encode index")
				}
			} catch {
				print("Failed to save index")
			}
		}
		
		func clear(){
			if (FileManager.default.fileExists(atPath: self.baseUrl.path)){
				do { try FileManager.default.removeItem(at: self.baseUrl) }
				catch { print("Failed to delete \(self.baseUrl.path), maybe it didn't exist yet?") }
			}
			self.taskIndex.removeAll()
		}
	}
}


protocol TaskRunner {
	func run(task: TaskManager.Task, completion: @escaping (Result<Bool, Error>) -> Void)
}


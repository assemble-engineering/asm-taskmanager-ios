import Foundation

public class TaskManager {
	public static let shared = TaskManager()
	var delegate: TaskManagerDelegate?
	let taskStore = TaskStore()
	var taskRunner: TaskRunner?
	var executingTasks = false
	let queue = DispatchQueue(label: "TaskManager", qos: .userInitiated)
	
	public enum TaskManagerError: Error {
		case missingTaskRunner
		case busyExecutingTasks
	}
	
	public func use(taskRunner: TaskRunner){
		queue.async {
			self.taskRunner = taskRunner
		}
	}
	
	public func manage(task: Task){
		queue.async {
			print("Storing task: \(task)")
			self.taskStore.store(task)
			self.delegate?.taskStoreChanged(taskManager: self)
		}
	}
	
	public func clearStore(completion: ((Result<Int, Error>) -> Void)? = nil) {
		queue.async {
			let nItems = self.taskStore.taskIndex.count
			self.taskStore.clear()
			if let c = completion {
				c(.success(nItems))
			}
		}
	}
	
	public var storeDescription: String {
		get {
			return "\(self.taskStore.taskIndex.count) items"
		}
	}
	
	public var numberOfStoredItems: Int {
		get {
			return self.taskStore.taskIndex.count
		}
	}
	
	public func executeTasks(completion: ((Result<Bool, Error>) -> Void)? = nil){
		queue.async {

			guard let taskRunner = self.taskRunner else {
				completion?(.failure(TaskManagerError.missingTaskRunner))
				return
			}
			
			if (self.executingTasks){
				print("Busy executing tasks, bailing from executeTasks")
				completion?(.failure(TaskManagerError.busyExecutingTasks))
				return
			}
			
			self.executingTasks = true
			let group = DispatchGroup()
			
			print("executeTasks enumerating \(self.taskStore.taskIndex.count) tasks")
			self.taskStore.taskIndex.forEach { (key, task) in
				group.enter()
				self.queue.async(group: group) {
					print("Executing task: \(task)")

					taskRunner.run(task: task){ result in
						self.queue.async {
							switch result {
								case .success(_):
									print ("### Executing Task Success")
									
									self.taskStore.remove(task) //because it should be done
									self.delegate?.taskStoreChanged(taskManager: self)

								case .failure(let error):
									print ("### Executing Task Error: \(error)")
							}
							group.leave()
						}
					}
				}
			}
			
//			let _ = group.wait(timeout: .now() + 10.0)
			
			group.notify(queue: self.queue){
				self.queue.async {
					self.executingTasks = false
					completion?(.success(true))
				}
			}
		}
	}
	
	
	// An task is an object that has an identifier and created date
	public struct Task: Codable {
		var identifier: String
		var createdAt: Date
		var contextData: Data
		
		public init<T: Encodable>(context: T){
			identifier = UUID().uuidString
			createdAt = Date()
			self.contextData = try! JSONEncoder().encode(context) //TODO: handle throw
		}
		
		public func context<T: Decodable>(as type: T.Type) -> T {
			return try! JSONDecoder().decode(type, from: self.contextData) //TODO: handle throw
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

		let cacheBaseDir = "com.asm.ASMContextManager/TaskStore"
		let cacheFileName = "TaskIndex.json"

		init() {
			self.loadIndex()
		}
		  
		var baseUrl: URL {
			get {
				/**
				Why we're using Library/Application Support/: "Remember that files in Documents/ and Application Support/ are backed up by default."
				In theory, this implies tasks can persist even across re-installs if user has iCloud backups going on.
				Why we're not using Library/Caches/: "Note that the system may delete the Caches/ directory to free up disk space, so your app must be able to re-create or download these files as needed."
				Why're not using tmp/: "The system will periodically purge these files when your app is not running; therefore, you cannot rely on these files persisting after your app terminates."
				*/
				let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
				return url!.appendingPathComponent("\(cacheBaseDir)")
			}
		}
		
		var indexUrl: URL {
			get {
				return baseUrl.appendingPathComponent(self.cacheFileName)
			}
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
				
				print("TaskStore saved to file \n\(fileUrl)")
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
			do {
				try FileManager.default.removeItem(at: fileUrl)
				self.saveIndex()
			} catch (let error) {
				print("Failed to remove file: \(fileUrl), ignoring error \(error)")
			}
		}
		
		func loadIndex() {
			do {
				let url = indexUrl
				//if url is nil, file doesn't exist
				let d = try Data(contentsOf:url)
					
				let decoder = JSONDecoder()
				self.taskIndex = try decoder.decode(TaskIndex.self, from: d)
				print("Loaded \(self.taskIndex.count) tasks")
			} catch {
				print("Failed to decode task index, index file probably doesn't exist yet")
			}
		}
		
		func saveIndex(){
			do {
				let url = indexUrl
					
				let encoder = JSONEncoder()
				let d = try encoder.encode(self.taskIndex)
				try d.write(to: url)
				print("Saved \(self.taskIndex.count) tasks to cache \(url)")
				
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
			self.saveIndex()
		}
	}
}

public protocol TaskManagerDelegate {
	func taskStoreChanged(taskManager: TaskManager)
}

public protocol TaskRunner {
	func run(task: TaskManager.Task, completion: @escaping (Swift.Result<Bool, Error>) -> Void)
}



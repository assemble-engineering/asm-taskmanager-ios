import Foundation

class TaskManager {
	static let shared = TaskManager()
	let queue = DispatchQueue(label: "Manager Queue")

	let taskStore = TaskStore()
	var taskRunner: TaskRunner?

	func use(taskRunner: TaskRunner){
		self.taskRunner = taskRunner
	}
	
	func manage(taskRecord: TaskRecord){
		queue.async {
			self.taskStore.store(taskRecord)
		}
	}
	
	func execute(taskRecord: TaskRecord){
		queue.async {
			if let taskRunner = self.taskRunner {
				taskRunner.run(taskRecord) { completedRecord in
					self.queue.async {
						// remove the task
						self.taskStore.remove(completedRecord)
					}
				}
			} else {
				print("No taskRunner, just storing")
			}
		}
	}
	
	func executeTasks(){
		taskStore.taskIndex.forEach { (key, taskRecord) in
			execute(taskRecord: taskRecord)
		}
	}
	
	// An task is an object that has an identifier and created date
	struct TaskRecord: Codable {
		var identifier: String
		var createdAt: Date
		var context: String
//		var taskState: TaskState

		init(context: String){
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

	typealias TaskIndex = [String: TaskRecord]

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
		
		
		func url(forTask task: TaskRecord) -> URL {
			return self.baseUrl.appendingPathComponent(task.identifier + ".task")
		}
		
		func store(_ record: TaskRecord){
				
			let fileUrl = self.url(forTask: record)
				
			do {
				let fileBaseUrl = fileUrl.deletingLastPathComponent()
				try FileManager.default.createDirectory(at: fileBaseUrl, withIntermediateDirectories: true, attributes: nil)
				let contentString = record.encode()
				try contentString.write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
				
				print("TaskStore saved \(record) to file \n\(fileUrl)")
				self.taskIndex[record.identifier] = record
				self.saveIndex()
			} catch {
				// failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
				print("Failed to write")
			}
		}
		
		func remove(_ record: TaskRecord){
			let fileUrl = self.url(forTask: record)
			print("Removing \(fileUrl)")
			self.taskIndex.removeValue(forKey: record.identifier)
			try! FileManager.default.removeItem(at: fileUrl)
		}
		
		func loadIndex() {
			 do {

				 print ("TaskStore")
				 
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
	}
}


protocol TaskRunner {
	func run(_ taskRecord: TaskManager.TaskRecord, completion: @escaping (TaskManager.TaskRecord) -> Void)
}

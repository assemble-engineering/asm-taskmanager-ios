import Foundation

class EventManager {
	static let shared = EventManager()
	let queue = DispatchQueue(label: "Manager Queue")

	let eventStore = EventStore()
	var eventRunner: EventRunner?

	func use(eventRunner: EventRunner){
		self.eventRunner = eventRunner
	}
	
	func manage(eventRecord: EventRecord){
		queue.async {
			self.eventStore.store(eventRecord)
		}
	}
	
	func execute(eventRecord: EventRecord){
		queue.async {
			if let eventRunner = self.eventRunner {
				eventRunner.run(eventRecord) { completedRecord in
					self.queue.async {
						// remove the event
						self.eventStore.remove(completedRecord)
					}
				}
			} else {
				print("No eventRunner, just storing")
			}
		}
	}
	
	func executeEvents(){
		eventStore.eventIndex.forEach { (key, eventRecord) in
			execute(eventRecord: eventRecord)
		}
	}
	
	// An event is an object that has an identifier and created date
	struct EventRecord: Codable {
		var identifier: String
		var createdAt: Date
		var context: String
//		var eventState: EventState

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

	typealias EventIndex = [String: EventRecord]

	class EventStore {
		var eventIndex = EventIndex()

		let cacheBaseDir = "com.asm.ASMContextManager/EventStore"
		let cacheFilePath = "com.asm.ASMContextManager/EventStore/EventIndex.json"
		
		var baseUrl: URL {
			get {
				let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
				return url!.appendingPathComponent("\(cacheBaseDir)")
			}
		}
		
		func url(forEvent event: EventRecord) -> URL {
			return self.baseUrl.appendingPathComponent(event.identifier + ".task")
		}
		
		func store(_ record: EventRecord){
				
			let fileUrl = self.url(forEvent: record)
				
			do {
				let fileBaseUrl = fileUrl.deletingLastPathComponent()
				try FileManager.default.createDirectory(at: fileBaseUrl, withIntermediateDirectories: true, attributes: nil)
				let contentString = record.encode()
				try contentString.write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
				
				print("EventStore saved \(record) to file \n\(fileUrl)")
				self.eventIndex[record.identifier] = record

			} catch {
				// failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
				print("Failed to write")
			}
		}
		
		func remove(_ record: EventRecord){
			let fileUrl = self.url(forEvent: record)
			print("Removing \(fileUrl)")
			self.eventIndex.removeValue(forKey: record.identifier)
			try! FileManager.default.removeItem(at: fileUrl)
		}
	}
}


protocol EventRunner {
	func run(_ eventRecord: EventManager.EventRecord, completion: @escaping (EventManager.EventRecord) -> Void)
}

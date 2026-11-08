import Foundation

enum TemporaryFiles {
	static func removeLeftovers(olderThan age: TimeInterval = 86_400) {
		DispatchQueue.global(qos: .utility).async {
			let fileManager = FileManager.default
			let keys: Set<URLResourceKey> = [.contentModificationDateKey]
			guard let items = try? fileManager.contentsOfDirectory(at: fileManager.temporaryDirectory, includingPropertiesForKeys: Array(keys)) else { return }
			let cutoff = Date().addingTimeInterval(-age)
			for item in items {
				let modified = (try? item.resourceValues(forKeys: keys))?.contentModificationDate ?? .distantPast
				if modified < cutoff { try? fileManager.removeItem(at: item) }
			}
		}
	}
}

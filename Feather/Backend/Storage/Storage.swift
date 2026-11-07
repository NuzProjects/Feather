//
//  Persistence.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import CoreData
import Foundation

// MARK: - Storage
final class Storage: ObservableObject {
	static let shared = Storage()
	let container: NSPersistentContainer
	
	private let _name: String = "Feather"

	init(inMemory: Bool = false) {
		container = NSPersistentContainer(name: _name)

		if inMemory {
			container.persistentStoreDescriptions.first?.url =
				URL(fileURLWithPath: "/dev/null")
		}
		
		container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
		container.persistentStoreDescriptions.first?.shouldInferMappingModelAutomatically = true

		_loadPersistentStoreSafely()
		container.viewContext.automaticallyMergesChangesFromParent = true
		container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
	}

	var context: NSManagedObjectContext {
		container.viewContext
	}
	
	func saveContext() {
		DispatchQueue.main.async {
			if self.context.hasChanges {
				try? self.context.save()
			}
		}
	}
	
	func clearContext<T: NSManagedObject>(request: NSFetchRequest<T>) {
		guard let request = request as? NSFetchRequest<NSFetchRequestResult> else { return }
		batchDelete(request)
	}
	
	func batchDelete(_ request: NSFetchRequest<NSFetchRequestResult>) {
		let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
		deleteRequest.resultType = .resultTypeObjectIDs
		guard
			let result = try? context.execute(deleteRequest) as? NSBatchDeleteResult,
			let ids = result.result as? [NSManagedObjectID],
			!ids.isEmpty
		else { return }
		NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: ids], into: [context])
	}
	
	private func _loadPersistentStoreSafely() {
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Feather could not open its database. Existing data has been preserved. \(error.localizedDescription)")
            }
        }
    }
}

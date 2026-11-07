import Foundation
import CoreData

@MainActor
enum FeatherTransfer {
	enum Failure: LocalizedError {
		case invalid, busy
		var errorDescription: String? {
			switch self {
			case .invalid: return "Choose a complete Feather backup folder exported from Settings → Backup & Transfer."
			case .busy: return "Wait for active downloads to finish before transferring data."
			}
		}
	}
	private static let entities = ["CertificatePair", "Imported", "Signed", "AltSource", "AppSourceMetadata"]
	static func export(includeApps: Bool = true) async throws -> URL {
		guard DownloadManager.shared.downloads.isEmpty else { throw Failure.busy }
		let context = Storage.shared.context
		try context.save()
		var records: [[String: Any]] = []
		let exported = includeApps ? entities : ["CertificatePair", "AltSource"]
		for name in exported where Storage.shared.container.managedObjectModel.entitiesByName[name] != nil {
			for object in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: name)) {
				var attributes: [String: Any] = [:]
				for (key, description) in object.entity.attributesByName {
					guard let value = object.value(forKey: key) else { continue }
					if description.attributeType == .URIAttributeType, let url = value as? URL { attributes[key] = url.absoluteString }
					else { attributes[key] = value }
				}
				var record: [String: Any] = ["entity": name, "attributes": attributes]
				if name == "Signed", let certificate = object.value(forKey: "certificate") as? NSManagedObject, let uuid = certificate.value(forKey: "uuid") as? String { record["certificate"] = uuid }
				records.append(record)
			}
		}
		let defaults = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]
		var manifest: [String: Any] = ["format": "FeatherTransfer", "version": 1, "home": NSHomeDirectory(), "records": records, "preferences": defaults, "settingsOnly": !includeApps]
		let request = NSFetchRequest<NSManagedObject>(entityName: "CertificatePair")
		request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
		let certificates = try context.fetch(request)
		let index = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		if certificates.indices.contains(index), let uuid = certificates[index].value(forKey: "uuid") as? String { manifest["selectedCertificate"] = uuid }
		let data = try PropertyListSerialization.data(fromPropertyList: manifest, format: .binary, options: 0)
		let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Feather Backup " + UUID().uuidString.prefix(8), isDirectory: true)
		let documents = URL.documentsDirectory
		return try await Task.detached(priority: .userInitiated) {
			try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
			do {
				try data.write(to: folder.appendingPathComponent("Manifest.plist"), options: .atomic)
				if includeApps { _ = try TransferFiles.merge(from: documents, to: folder.appendingPathComponent("Documents")) }
				else {
					let certificates = documents.appendingPathComponent("Certificates")
					let target = folder.appendingPathComponent("Documents/Certificates")
					try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
					if FileManager.default.fileExists(atPath: certificates.path) { _ = try TransferFiles.merge(from: certificates, to: target) }
				}
				return folder
			} catch { try? FileManager.default.removeItem(at: folder); throw error }
		}.value
	}
	static func restore(_ folder: URL) async throws -> Int {
		guard DownloadManager.shared.downloads.isEmpty else { throw Failure.busy }
		let accessed = folder.startAccessingSecurityScopedResource()
		defer { if accessed { folder.stopAccessingSecurityScopedResource() } }
		let data = try Data(contentsOf: folder.appendingPathComponent("Manifest.plist"))
		guard let manifest = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
			  manifest["format"] as? String == "FeatherTransfer", manifest["version"] as? Int == 1,
			  let records = manifest["records"] as? [[String: Any]], let preferences = manifest["preferences"] as? [String: Any] else { throw Failure.invalid }
		let context = Storage.shared.context
		try context.save()
		let oldHome = manifest["home"] as? String ?? ""
		var existing: [String: NSManagedObject] = [:]
		func key(_ entity: String, _ attributes: [String: Any]) throws -> String {
			let identity: String?
			if entity == "AltSource" { identity = attributes["identifier"] as? String }
			else if entity == "AppSourceMetadata", let uuid = attributes["appUUID"] as? String, let kind = attributes["appKind"] as? String { identity = uuid + ":" + kind }
			else { identity = attributes["uuid"] as? String }
			guard let identity, !identity.isEmpty else { throw Failure.invalid }
			return entity + ":" + identity
		}
		for name in entities {
			for object in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: name)) {
				existing[try key(name, object.dictionaryWithValues(forKeys: Array(object.entity.attributesByName.keys)))] = object
			}
		}
		for record in records {
			guard let entity = record["entity"] as? String, entities.contains(entity), let attributes = record["attributes"] as? [String: Any] else { throw Failure.invalid }
			_ = try key(entity, attributes)
			if entity != "AltSource" {
				let uuid = attributes[entity == "AppSourceMetadata" ? "appUUID" : "uuid"] as? String
				guard uuid.flatMap(UUID.init(uuidString:)) != nil else { throw Failure.invalid }
			}
			if let certificate = record["certificate"] as? String, UUID(uuidString: certificate) == nil { throw Failure.invalid }
			guard let description = Storage.shared.container.managedObjectModel.entitiesByName[entity] else { throw Failure.invalid }
			for (name, attribute) in description.attributesByName where !attribute.isOptional && attribute.defaultValue == nil {
				guard attributes[name] != nil else { throw Failure.invalid }
			}
			for (name, value) in attributes {
				guard let attribute = description.attributesByName[name] else { continue }
				let valid: Bool
				switch attribute.attributeType {
				case .stringAttributeType: valid = value is String
				case .dateAttributeType: valid = value is Date
				case .booleanAttributeType, .integer16AttributeType, .integer32AttributeType, .integer64AttributeType, .doubleAttributeType, .floatAttributeType: valid = value is NSNumber
				case .URIAttributeType: valid = (value as? String).flatMap(URL.init(string:)) != nil
				case .binaryDataAttributeType: valid = value is Data
				default: valid = false
				}
				guard valid else { throw Failure.invalid }
			}
		}
		let source = folder.appendingPathComponent("Documents", isDirectory: true)
		let destination = URL.documentsDirectory
		let created = try await Task.detached(priority: .userInitiated) { try TransferFiles.merge(from: source, to: destination) }.value
		var inserted: [String: NSManagedObject] = [:]
		do {
			for record in records {
				let entity = record["entity"] as! String
				let attributes = record["attributes"] as! [String: Any]
				let identifier = try key(entity, attributes)
				if existing[identifier] != nil { continue }
				let object = NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
				for (name, description) in object.entity.attributesByName {
					guard let raw = attributes[name] else { continue }
					let value = rebase(raw, from: oldHome)
					if description.attributeType == .URIAttributeType { object.setValue((value as? String).flatMap(URL.init(string:)), forKey: name) }
					else { object.setValue(value, forKey: name) }
				}
				existing[identifier] = object; inserted[identifier] = object
			}
			for record in records where record["entity"] as? String == "Signed" {
				let identity = try key("Signed", record["attributes"] as! [String: Any])
				if let object = inserted[identity], let uuid = record["certificate"] as? String {
					object.setValue(existing["CertificatePair:" + uuid], forKey: "certificate")
				}
			}
			try context.save()
		} catch {
			context.rollback()
			for url in created.reversed() { try? FileManager.default.removeItem(at: url) }
			throw error
		}
		for (name, value) in preferences { UserDefaults.standard.set(rebase(value, from: oldHome), forKey: name) }
		if let uuid = manifest["selectedCertificate"] as? String {
			let request = NSFetchRequest<NSManagedObject>(entityName: "CertificatePair")
			request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
			if let index = try context.fetch(request).firstIndex(where: { $0.value(forKey: "uuid") as? String == uuid }) { UserDefaults.standard.set(index, forKey: "feather.selectedCert") }
		}
		return inserted.count
	}
	private static func rebase(_ value: Any, from oldHome: String) -> Any {
		if let text = value as? String { return oldHome.isEmpty ? text : text.replacingOccurrences(of: oldHome, with: NSHomeDirectory()) }
		if let values = value as? [String: Any] { return values.mapValues { rebase($0, from: oldHome) } }
		if let values = value as? [Any] { return values.map { rebase($0, from: oldHome) } }
		if let data = value as? Data, let json = try? JSONSerialization.jsonObject(with: data), let output = try? JSONSerialization.data(withJSONObject: rebase(json, from: oldHome), options: [.fragmentsAllowed]) { return output }
		return value
	}
}

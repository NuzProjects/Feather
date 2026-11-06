import Foundation
import Security

// Keep in sync with Feather/Backend/Widgets/WidgetSnapshot.swift
struct WidgetSnapshot: Codable, Equatable {
	struct Certificate: Codable, Equatable {
		var name: String
		var expiration: Date?
		var revoked: Bool
	}

	struct App: Codable, Equatable {
		var name: String
		var version: String?
		var date: Date?
		var icon: Data?
	}

	var tint: String
	var certificate: Certificate?
	var signedCount: Int
	var importedCount: Int
	var recent: [App]
	var updated: Date
}

// Sideload certificates rarely include app groups, so the app and the widgets
// share data through a keychain access group under the same team prefix.
enum WidgetSnapshotStore {
	private static let service = "Feather.Widgets"
	private static let account = "snapshot"

	static let accessGroup: String? = {
		let probe: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: "Feather.Widgets.probe",
			kSecAttrAccount as String: "probe",
			kSecReturnAttributes as String: true
		]
		var result: CFTypeRef?
		var status = SecItemCopyMatching(probe as CFDictionary, &result)
		if status == errSecItemNotFound {
			var add = probe
			add[kSecValueData as String] = Data()
			add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
			status = SecItemAdd(add as CFDictionary, &result)
		}
		guard
			status == errSecSuccess,
			let attributes = result as? [String: Any],
			let group = attributes[kSecAttrAccessGroup as String] as? String,
			let prefix = group.split(separator: ".").first
		else { return nil }
		return "\(prefix).feather.widgets"
	}()

	private static func query() -> [String: Any]? {
		guard let accessGroup else { return nil }
		return [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
			kSecAttrAccessGroup as String: accessGroup
		]
	}

	static func read() -> WidgetSnapshot? {
		guard var query = query() else { return nil }
		query[kSecReturnData as String] = true
		var result: CFTypeRef?
		guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970
		return try? decoder.decode(WidgetSnapshot.self, from: data)
	}

	@discardableResult
	static func write(_ snapshot: WidgetSnapshot) -> Bool {
		guard let query = query() else { return false }
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .secondsSince1970
		guard let data = try? encoder.encode(snapshot) else { return false }
		let attributes: [String: Any] = [
			kSecValueData as String: data,
			kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
		]
		var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
		if status == errSecItemNotFound {
			status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
		}
		return status == errSecSuccess
	}
}

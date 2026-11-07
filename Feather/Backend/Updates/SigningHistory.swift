import Foundation

@MainActor
final class SigningHistory {
	static let shared = SigningHistory()
	private var entries: [String: Options] = [:]
	private init() {
		if let data = UserDefaults.standard.data(forKey: "Signing.history"), let saved = try? JSONDecoder().decode([String: Options].self, from: data) { entries = saved }
	}
	func options(for uuid: String?) -> Options? {
		guard let uuid else { return nil }; return entries[uuid]
	}
	func record(_ options: Options, for uuid: String) { entries[uuid] = options; save() }
	func remove(_ uuid: String?) {
		guard let uuid else { return }; entries.removeValue(forKey: uuid); save()
	}
	private func save() {
		if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: "Signing.history") }
	}
}

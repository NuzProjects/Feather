import Foundation
import SwiftUI

struct RemoteConfigData: Codable, Equatable {
	struct Announcement: Codable, Equatable {
		let id: String
		let title: String
		let message: String
		let buttonTitle: String?
		let url: URL?
		let maxVersion: String?
	}

	struct Provider: Codable, Equatable, Identifiable {
		let name: String
		let detail: String
		let url: URL
		let icon: String?
		let official: Bool?
		var iconURL: URL? = nil
		var id: String { url.absoluteString }
	}

	var announcement: Announcement?
	var certificateProviders: [Provider]?
	var featuredSources: [URL]?
	var plistServer: URL?
	var flags: [String: Bool]?
}

@MainActor
final class RemoteConfig: ObservableObject {
	static let shared = RemoteConfig()
	static let url = URL(string: "https://raw.githubusercontent.com/NuzProjects/Feather/main/remote-config.json")!

	private static let cacheKey = "RemoteConfig.cache"
	private static let seenAnnouncementKey = "RemoteConfig.seenAnnouncement"

	@Published private(set) var data: RemoteConfigData
	private var lastFetch = Date.distantPast

	private init() {
		data = Self.cached ?? RemoteConfigData()
	}

	nonisolated static var cached: RemoteConfigData? {
		guard let saved = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
		return try? JSONDecoder().decode(RemoteConfigData.self, from: saved)
	}

	func refresh(force: Bool = false) async {
		guard force || Date().timeIntervalSince(lastFetch) > 900 else { return }
		lastFetch = Date()
		var request = URLRequest(url: Self.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
		request.setValue("MadeByNuz-Feather", forHTTPHeaderField: "User-Agent")
		do {
			let (body, response) = try await URLSession.shared.data(for: request)
			guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
			let decoded = try JSONDecoder().decode(RemoteConfigData.self, from: body)
			UserDefaults.standard.set(body, forKey: Self.cacheKey)
			if decoded != data { data = decoded }
			try? await Task.sleep(nanoseconds: 2_500_000_000)
			_showAnnouncementIfNeeded()
		} catch {
			DevLog.shared.error(error, while: "Loading remote settings", category: "RemoteConfig")
		}
	}

	func flag(_ name: String, default value: Bool = false) -> Bool {
		data.flags?[name] ?? value
	}

	private func _showAnnouncementIfNeeded() {
		guard
			let announcement = data.announcement,
			UserDefaults.standard.string(forKey: Self.seenAnnouncementKey) != announcement.id
		else { return }
		if
			let maxVersion = announcement.maxVersion,
			let max = FeatherUpdater.versionKey(maxVersion),
			let current = FeatherUpdater.versionKey(FeatherUpdater.shared.currentVersion),
			max.lexicographicallyPrecedes(current)
		{
			return
		}
		UserDefaults.standard.set(announcement.id, forKey: Self.seenAnnouncementKey)

		var actions: [UIAlertAction] = []
		if let url = announcement.url {
			actions.append(UIAlertAction(title: announcement.buttonTitle ?? "Open", style: .default) { _ in
				UIApplication.shared.open(url)
			})
		}
		actions.append(UIAlertAction(title: "OK", style: actions.isEmpty ? .default : .cancel))
		UIAlertController.showAlert(title: announcement.title, message: announcement.message, actions: actions)
	}
}

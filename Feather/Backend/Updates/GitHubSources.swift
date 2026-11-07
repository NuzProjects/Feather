import Foundation
import Combine

final class GitHubSources: ObservableObject {
	static let shared = GitHubSources()
	@Published private(set) var repositories: [GitHubRepository] = []
	/// When each repository last published a release with an IPA, by slug.
	@Published private(set) var lastUpdated: [String: Date] = [:]
	private var lastRefresh = Date.distantPast

	private init() {
		reload()
		if let saved = UserDefaults.standard.dictionary(forKey: "GitHub.sourceDates") as? [String: Date] { lastUpdated = saved }
	}

	func reload() {
		repositories = (UserDefaults.standard.data(forKey: "GitHub.sources").flatMap { try? JSONDecoder().decode([GitHubRepository].self, from: $0) }) ?? []
	}

	func add(_ repository: GitHubRepository) {
		guard !repositories.contains(where: { $0.slug.lowercased() == repository.slug.lowercased() }) else { return }
		repositories.append(repository); save()
	}

	func remove(_ repository: GitHubRepository) {
		repositories.removeAll { $0 == repository }
		lastUpdated.removeValue(forKey: repository.slug)
		save()
	}

	@MainActor
	func refreshDates(force: Bool = false) async {
		// New repositories are looked up straight away; the rest every half hour.
		let stale = force || Date().timeIntervalSince(lastRefresh) > 1800
		let targets = repositories.filter { stale || lastUpdated[$0.slug] == nil }
		guard !targets.isEmpty else { return }
		if stale { lastRefresh = Date() }
		let formatter = ISO8601DateFormatter()
		for repository in targets {
			guard let releases = try? await GitHubReleases.shared.releases(repository) else { continue }
			if let newest = releases.compactMap({ $0.published_at.flatMap(formatter.date(from:)) }).max() {
				lastUpdated[repository.slug] = newest
			}
		}
		UserDefaults.standard.set(lastUpdated, forKey: "GitHub.sourceDates")
	}

	private func save() {
		if let data = try? JSONEncoder().encode(repositories) { UserDefaults.standard.set(data, forKey: "GitHub.sources") }
		UserDefaults.standard.set(lastUpdated, forKey: "GitHub.sourceDates")
	}
}

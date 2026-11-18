import Foundation
import AltSourceKit
import SwiftUI
import CryptoKit

final class SourcesViewModel: ObservableObject {
	static let shared = SourcesViewModel()

	private static let cacheFolder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Sources", isDirectory: true)

	var isFinished = true
	@Published var sources: [AltSource: ASRepository] = [:]
	private var _refreshedThisLaunch: Set<URL> = []

	func fetchSources(_ sources: FetchedResults<AltSource>, refresh: Bool = false, batchSize: Int = 4) async {
		guard isFinished else { return }
		let sourcesArray = Array(sources)

		await _showSaved(sourcesArray)

		let refreshed = await MainActor.run { _refreshedThisLaunch }
		if !refresh, sourcesArray.allSatisfy({ source in source.sourceURL.map { refreshed.contains($0) } ?? true }) { return }

		isFinished = false
		defer { isFinished = true }

		await MainActor.run {
			self.sources = self.sources.filter { sourcesArray.contains($0.key) }
		}

		for startIndex in stride(from: 0, to: sourcesArray.count, by: batchSize) {
			let batch = sourcesArray[startIndex..<min(startIndex + batchSize, sourcesArray.count)]

			let batchResults = await withTaskGroup(of: (AltSource, ASRepository?).self, returning: [AltSource: ASRepository].self) { group in
				for source in batch {
					group.addTask {
						guard let url = source.sourceURL else { return (source, nil) }
						return (source, await Self._download(url))
					}
				}
				var results = [AltSource: ASRepository]()
				for await (source, repository) in group {
					if let repository { results[source] = repository }
				}
				return results
			}

			await MainActor.run {
				for (source, repository) in batchResults {
					self.sources[source] = repository
					if let url = source.sourceURL { _refreshedThisLaunch.insert(url) }
				}
			}
		}
	}

	private func _showSaved(_ sourcesArray: [AltSource]) async {
		let missing = await MainActor.run { sourcesArray.filter { self.sources[$0] == nil } }
		guard !missing.isEmpty else { return }
		let saved = missing.compactMap { source -> (AltSource, ASRepository)? in
			guard let url = source.sourceURL, let repository = Self._savedRepository(url) else { return nil }
			return (source, repository)
		}
		guard !saved.isEmpty else { return }
		await MainActor.run {
			for (source, repository) in saved where self.sources[source] == nil {
				self.sources[source] = repository
			}
		}
	}

	private static func _download(_ url: URL) async -> ASRepository? {
		guard
			let (data, _) = try? await URLSession.shared.data(from: url),
			let repository = try? JSONDecoder().decode(ASRepository.self, from: data)
		else { return nil }
		try? FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
		try? data.write(to: _cacheFile(for: url), options: .atomic)
		return repository
	}

	private static func _savedRepository(_ url: URL) -> ASRepository? {
		guard let data = try? Data(contentsOf: _cacheFile(for: url)) else { return nil }
		return try? JSONDecoder().decode(ASRepository.self, from: data)
	}

	private static func _cacheFile(for url: URL) -> URL {
		let name = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
		return cacheFolder.appendingPathComponent("\(name).json")
	}
}

//
//  SourcesAddView.swift
//  Feather
//
//  Created by samara on 1.05.2025.
//

import SwiftUI
import NimbleViews
import AltSourceKit
import NimbleJSON
import OSLog
import UIKit.UIImpactFeedbackGenerator

// MARK: - View
struct SourcesAddView: View {
	typealias RepositoryDataHandler = Result<ASRepository, Error>
	@Environment(\.dismiss) var dismiss

	private let _dataService = NBFetchService()
	
	@State private var _filteredRecommendedSourcesData: [(url: URL, data: ASRepository)] = []
	private func _refreshFilteredRecommendedSourcesData() {
		let filtered = recommendedSourcesData
			.filter { (url, data) in
				let id = data.id ?? url.absoluteString
				return !Storage.shared.sourceExists(id)
			}
			.sorted { lhs, rhs in
				(recommendedSources.firstIndex(of: lhs.url) ?? .max) < (recommendedSources.firstIndex(of: rhs.url) ?? .max)
			}
		_filteredRecommendedSourcesData = filtered
	}
	
	@State var recommendedSourcesData: [(url: URL, data: ASRepository)] = []
	/// Featured sources: `featuredSources` in remote-config.json replaces the built-in list when present.
	var recommendedSources: [URL] {
		if let remote = RemoteConfig.cached?.featuredSources, !remote.isEmpty { return remote }
		return Self.builtInRecommendedSources
	}
	
	static let builtInRecommendedSources: [URL] = [
		"https://cdn.altstore.io/file/altstore/apps.json",
		"https://github.com/LiveContainer/LiveContainer/releases/download/nightly/apps_nightly.json",
		"https://alt.getutm.app",
		"https://provenance-emu.com/apps.json",
		"https://ish.app/altstore.json",
		"https://stikdebug.xyz/index.json",
		"https://apps.manicemu.site/altstore",
		"https://altstore.oatmealdome.me/",
		"https://pokemmo.com/altstore",
		"https://raw.githubusercontent.com/Aidoku/Aidoku/altstore/apps.json",
		"https://xitrix.github.io/iTorrent/AltStore.json",
		"https://alt.crystall1ne.dev",
		"https://mikevillarroel.github.io/mikebuilds-source/originals.json",
		"https://raw.githubusercontent.com/NuzProjects/Feather/refs/heads/main/source.json"
	].map { URL(string: $0)! }
	
	@State private var _isImporting = false
	@State private var _sourceURL = ""
	
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Add Source"), displayMode: .inline) {
			Form {
				NBSection(.localized("Source URL")) {
					TextField(.localized("Enter Source URL"), text: $_sourceURL)
						.keyboardType(.URL)
						.textInputAutocapitalization(.never)
				} footer: {
					Text(.localized("The only supported repositories are AltStore repositories."))
					Text(verbatim: "[\(String.localized("Learn more about how to setup a repository..."))](https://faq.altstore.io/developers/make-a-source)")
				}
				
				Section {
					Button(.localized("Import"), systemImage: "square.and.arrow.down") {
						_isImporting = true
						_fetchImportedRepositories(UIPasteboard.general.string) {
							dismiss()
						}
					}
					
					Button(.localized("Export"), systemImage: "doc.on.doc") {
						let sources = Storage.shared.getSources()
						guard !sources.isEmpty else {
							UIAlertController.showAlertWithOk(
								title: .localized("Error"),
								message: .localized("No sources to export")
							)
							return
						}
						UIPasteboard.general.string = sources.map {
							$0.sourceURL!.absoluteString
						}.joined(separator: "\n")
						UIAlertController.showAlertWithOk(
							title: .localized("Success"),
							message: .localized("Sources copied to clipboard")
						) {
							dismiss()
						}
					}
				} footer: {
					Text(.localized("Supports importing from KravaSign/MapleSign and ESign."))
				}
				
				if !_filteredRecommendedSourcesData.isEmpty {
					NBSection(.localized("Featured")) {
						ForEach(_filteredRecommendedSourcesData, id: \.url) { (url, source) in
							NavigationLink {
								SourcePreviewView(url: url, repository: source)
							} label: {
								HStack(spacing: 2) {
									FRIconCellView(
										title: source.name ?? .localized("Unknown"),
										subtitle: url.absoluteString,
										iconUrl: source.currentIconURL
									)
									Button {
										Storage.shared.addSource(url, repository: source) { _ in
											_refreshFilteredRecommendedSourcesData()
										}
									} label: {
										NBButton(.localized("Add"), systemImage: "arrow.down", style: .text)
									}
									.buttonStyle(.borderless)
								}
							}
						}
					} footer: {
						Text(.localized("Open an [issue](https://github.com/NuzProjects/Feather/issues) on GitHub if you want your source to be featured."))
					}
				}
			}
			.toolbar {
				NBToolbarButton(role: .cancel)
				
				if !_isImporting {
					NBToolbarButton(
						.localized("Save"),
						style: .text,
						placement: .confirmationAction,
						isDisabled: _sourceURL.isEmpty
					) {
						FR.handleSource(_sourceURL) {
							dismiss()
						}
					}
				} else {
					ToolbarItem(placement: .confirmationAction) {
						ProgressView()
					}
				}
			}
			.onAppear(perform: _refreshFilteredRecommendedSourcesData)
			.animation(.default, value: _filteredRecommendedSourcesData.map { $0.data.id ?? "" })
			.task {
				await _fetchRecommendedRepositories()
			}
		}
	}
	
	private func _fetchRecommendedRepositories() async {
		let fetched = await _concurrentFetchRepositories(from: recommendedSources)
		await MainActor.run {
			recommendedSourcesData = fetched
			_refreshFilteredRecommendedSourcesData()
		}
	}
	
	private func _fetchImportedRepositories(
		_ code: String?,
		competion: @escaping () -> Void
	) {
		let repoUrls = code.map { ASDeobfuscator(with: $0).decode().compactMap { URL(string: $0) } } ?? []
		guard !repoUrls.isEmpty else {
			_isImporting = false
			UIAlertController.showAlertWithOk(
				title: .localized("Import"),
				message: "No sources were found on the clipboard. Copy the sources exported from KravaSign, MapleSign or ESign, then tap Import again."
			)
			return
		}
		
		Task {
			let fetched = await _concurrentFetchRepositories(from: repoUrls)
			
			let dict = Dictionary(fetched, uniquingKeysWith: { first, _ in first })

			await MainActor.run {
				Storage.shared.addSources(repos: dict) { _ in
					competion()
				}
			}
		}
	}
	
	private func _concurrentFetchRepositories(
		from urls: [URL]
	) async -> [(url: URL, data: ASRepository)] {
		let dataService = _dataService
		
		// Each fetch returns its own result, so nothing is lost or written from two threads at once.
		return await withTaskGroup(of: (url: URL, data: ASRepository)?.self) { group in
			for url in urls {
				group.addTask {
					await withCheckedContinuation { continuation in
						dataService.fetch<ASRepository>(from: url) { (result: RepositoryDataHandler) in
							switch result {
							case .success(let repo):
								continuation.resume(returning: (url: url, data: repo))
							case .failure(let error):
								Logger.misc.error("Failed to fetch \(url): \(error.localizedDescription)")
								continuation.resume(returning: nil)
							}
						}
					}
				}
			}
			var results: [(url: URL, data: ASRepository)] = []
			for await result in group {
				if let result { results.append(result) }
			}
			return results
		}
	}

}

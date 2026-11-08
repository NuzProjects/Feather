import CoreData
import AltSourceKit
import SwiftUI
import NimbleViews

struct SourcesView: View {
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@ObservedObject private var githubSources = GitHubSources.shared
	@StateObject var viewModel = SourcesViewModel.shared
	@State private var _isAddingPresenting = false
	@State private var _addingSourceLoading = false
	@State private var _searchText = ""

	private var _filteredSources: [AltSource] {
		_sources.filter {
			_searchText.isEmpty
			|| ($0.name?.localizedCaseInsensitiveContains(_searchText) ?? false)
			|| ($0.sourceURL?.absoluteString.localizedCaseInsensitiveContains(_searchText) ?? false)
		}
	}

	private var _filteredRepositories: [GitHubRepository] {
		githubSources.repositories.filter {
			_searchText.isEmpty || $0.slug.localizedCaseInsensitiveContains(_searchText)
		}
	}

	private struct _AppMatch: Identifiable {
		let source: AltSource
		let repository: ASRepository
		let app: ASRepository.App
		var id: String { "\(source.objectID.uriRepresentation().absoluteString)|\(app.currentUniqueId)" }
	}

	private var _matchingApps: [_AppMatch] {
		guard !_searchText.isEmpty else { return [] }
		let matches = _sources.flatMap { source -> [_AppMatch] in
			guard let repository = viewModel.sources[source] else { return [] }
			return repository.apps
				.filter { $0.currentName.localizedCaseInsensitiveContains(_searchText) }
				.map { _AppMatch(source: source, repository: repository, app: $0) }
		}
		return Array(matches.prefix(50))
	}

	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>

	var body: some View {
		NBNavigationView(.localized("Sources")) {
			NBListAdaptable {
				if !_filteredRepositories.isEmpty {
					NBSection(
						"GitHub",
						secondary: _filteredRepositories.count.description
					) {
						ForEach(_filteredRepositories) { repository in
							NavigationLink {
								GitHubImportView(repository: repository)
							} label: {
								GitHubSourceCellView(repository: repository)
							}
							.buttonStyle(.plain)
						}
					}
				}
				if !_filteredSources.isEmpty {
					Section {
						NavigationLink {
							SourceAppsView(object: Array(_sources), viewModel: viewModel)
						} label: {
							let isRegular = horizontalSizeClass != .compact
							HStack(spacing: 18) {
								Image("Repositories").appIconStyle()
								NBTitleWithSubtitleView(
									title: .localized("All Repositories"),
									subtitle: .localized("See all apps from your sources")
								)
							}
							.padding(isRegular ? 12 : 0)
							.background(
								isRegular
									? RoundedRectangle(cornerRadius: 18, style: .continuous)
									.fill(Color(.quaternarySystemFill))
									: nil
							)
						}
						.buttonStyle(.plain)
					}

					NBSection(
						.localized("Repositories"),
						secondary: _filteredSources.count.description
					) {
						ForEach(_filteredSources) { source in
							NavigationLink {
								SourceAppsView(object: [source], viewModel: viewModel)
							} label: {
								SourcesCellView(source: source)
							}
							.buttonStyle(.plain)
						}
					}
				}

				if !_matchingApps.isEmpty {
					NBSection("Apps", secondary: _matchingApps.count.description) {
						ForEach(_matchingApps) { match in
							NavigationLink {
								SourceAppsDetailView(sourceURL: match.source.sourceURL, source: match.repository, app: match.app)
							} label: {
								FRIconCellView(
									title: match.app.currentName,
									subtitle: match.source.name ?? "",
									iconUrl: match.app.iconURL
								)
							}
							.buttonStyle(.plain)
						}
					}
				}
			}
			.searchable(text: $_searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search sources and apps")
			.overlay {
				if _filteredSources.isEmpty && _matchingApps.isEmpty && _filteredRepositories.isEmpty {
					if #available(iOS 17, *) {
						ContentUnavailableView {
							Label(.localized("No Repositories"), systemImage: "globe.desk.fill")
						} description: {
							Text(.localized("Get started by adding your first repository."))
						} actions: {
							Button {
								_isAddingPresenting = true
							} label: {
								NBButton(.localized("Add Source"), style: .text)
							}
						}
					}
				}
			}
			.toolbar {
				NBToolbarButton(
					systemImage: "plus",
					style: .icon,
					placement: .topBarTrailing,
					isDisabled: _addingSourceLoading
				) {
					_isAddingPresenting = true
				}
			}
			.refreshable {
				await viewModel.fetchSources(_sources, refresh: true)
				await githubSources.refreshDates(force: true)
			}
			.sheet(isPresented: $_isAddingPresenting) {
				SourcesAddView()
			}
		}
		.task(id: Array(_sources)) {
			await viewModel.fetchSources(_sources)
		}
		.task(id: githubSources.repositories) {
			await githubSources.refreshDates()
		}
	}
}

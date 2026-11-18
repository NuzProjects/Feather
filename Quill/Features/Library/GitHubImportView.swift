import SwiftUI
import NimbleViews
import UserNotifications
struct GitHubImportView: View {
	@Environment(\.dismiss) private var dismiss
	@State private var input = ""
	@State private var repository: GitHubRepository?
	@State private var releases: [GitHubRelease] = []
	@State private var busy = false
	@State private var error: String?
	@State private var notify = true
	@State private var offerSource = false
	@State private var prompted: Set<String> = []
	private let pinned: GitHubRepository?
	init(repositoryInput: String = "") {
		_input = State(initialValue: repositoryInput)
		pinned = nil
	}
	init(repository: GitHubRepository) {
		_input = State(initialValue: repository.slug)
		pinned = repository
	}
	var body: some View {
		if let pinned {
			_form
				.navigationTitle(pinned.name)
				.navigationBarTitleDisplayMode(.inline)
		} else {
			NavigationStack {
				_form
					.navigationTitle("Import from GitHub")
					.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(busy) } }
					.interactiveDismissDisabled(busy)
			}
		}
	}
	private var _form: some View {
		Form {
			if pinned == nil {
				Section("Repository") {
					TextField("owner/repository or GitHub URL", text: $input).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
					Button("Find Releases") { Task { await load() } }.disabled(busy || input.isEmpty)
				}
			}
			Section {
				Toggle("Notify About Updates", isOn: $notify)
			} footer: { Text("Checks run when you open the app and when iOS allows background refresh. Updates install only when you choose Update.") }
			if busy { ProgressView("Working…") }
			if let error { Section { Text(error).foregroundStyle(.red).textSelection(.enabled) } }
			if let latest = _sortedReleases.first {
				Section("Latest Release") {
					ForEach(latest.ipaAssets) { asset in
						_assetRow(latest, asset)
					}
				}
			}
			if _sortedReleases.count > 1 {
				Section {
					DisclosureGroup {
						ForEach(_sortedReleases.dropFirst()) { release in
							ForEach(release.ipaAssets) { asset in
								_assetRow(release, asset)
							}
						}
					} label: {
						LabeledContent("Older Versions", value: "\(_sortedReleases.count - 1)")
					}
				}
			}
		}
		.nbReadableWidth()
		.nbSoftTopEdge()
		.refreshable { if pinned != nil { await load() } }
		.task { if !input.isEmpty && releases.isEmpty { await load() } }
		.alert("Add to Sources?", isPresented: $offerSource) {
			Button("Add to Sources") { if let repository { GitHubSources.shared.add(repository) } }
			Button("Not Now", role: .cancel) {}
		} message: { Text("Keep this GitHub repository in Sources to browse its IPA releases later.") }
	}
	private var _sortedReleases: [GitHubRelease] {
		releases.sorted { ($0.published_at ?? "") > ($1.published_at ?? "") }
	}

	private func _caption(for release: GitHubRelease) -> String {
		let name = release.name.flatMap { $0.isEmpty ? nil : $0 } ?? release.tag_name
		guard let published = release.published_at.flatMap(ISO8601DateFormatter().date(from:)) else { return name }
		return "\(name) · \(published.formatted(date: .abbreviated, time: .omitted))"
	}

	private func _assetRow(_ release: GitHubRelease, _ asset: GitHubAsset) -> some View {
		Button { Task { await importIPA(release, asset) } } label: {
			HStack(spacing: 12) {
				VStack(alignment: .leading, spacing: 2) {
					Text(asset.name)
						.foregroundStyle(.primary)
						.lineLimit(1)
					Text(_caption(for: release))
						.font(.caption)
						.foregroundStyle(Color(uiColor: .secondaryLabel))
						.lineLimit(1)
				}
				Spacer(minLength: 8)
				Text("Get")
					.font(.subheadline.bold())
					.padding(.horizontal, 16)
					.padding(.vertical, 6)
					.background(Color.accentColor.opacity(0.15), in: Capsule())
					.foregroundStyle(Color.accentColor)
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.disabled(busy)
	}

	private func load() async {
		busy = true; error = nil; releases = []; defer { busy = false }
		do {
			let repo = try GitHubRepository(input)
			let found = try await GitHubReleases.shared.releases(repo)
			guard !found.isEmpty else { throw ReleaseError.noIPA }
			repository = repo; releases = found
			if !GitHubSources.shared.repositories.contains(where: { $0.slug.lowercased() == repo.slug.lowercased() }), prompted.insert(repo.slug.lowercased()).inserted { offerSource = true }
		} catch { self.error = error.localizedDescription }
	}
	private func importIPA(_ release: GitHubRelease, _ asset: GitHubAsset) async {
		guard let repository else { return }
		busy = true; error = nil; defer { busy = false }
		do {
			if notify { _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) }
			try await GitHubReleases.shared.importAsset(GitHubTracking(repository: repository, release: release, asset: asset, notifications: notify))
			GitHubReleases.schedule(); dismiss()
		} catch { self.error = error.localizedDescription }
	}
}

import SwiftUI
import NimbleViews
import NukeUI
import UserNotifications

// MARK: - Repository info
struct GitHubRepositoryInfo: Decodable {
	struct Owner: Decodable { let login: String; let avatar_url: URL? }
	struct License: Decodable { let spdx_id: String?; let name: String? }
	let full_name: String
	let description: String?
	let stargazers_count: Int?
	let html_url: URL?
	let owner: Owner?
	let license: License?
	let language: String?

	static func fetch(_ repository: GitHubRepository) async throws -> GitHubRepositoryInfo {
		var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository.slug)")!)
		request.timeoutInterval = 30
		request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
		request.setValue("MadeByNuz-Feather", forHTTPHeaderField: "User-Agent")
		let (data, response) = try await URLSession.shared.data(for: request)
		guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ReleaseError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0) }
		return try JSONDecoder().decode(GitHubRepositoryInfo.self, from: data)
	}
}

extension GitHubRelease {
	var publishedDate: Date? { published_at.flatMap { ISO8601DateFormatter().date(from: $0) } }
	var displayVersion: String { name?.isEmpty == false ? name! : tag_name }
}

// MARK: - View
struct GitHubSourceDetailView: View {
	let repository: GitHubRepository

	@State private var _info: GitHubRepositoryInfo?
	@State private var _releases: [GitHubRelease] = []
	@State private var _isLoading = true
	@State private var _error: String?

	private var _latest: GitHubRelease? {
		_releases.sorted { ($0.published_at ?? "") > ($1.published_at ?? "") }.first
	}

	private var _iconURL: URL? {
		_info?.owner?.avatar_url ?? URL(string: "https://github.com/\(repository.owner).png")
	}

	// MARK: Body
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 10) {
				HStack(spacing: 10) {
					LazyImage(url: _iconURL) { state in
						if let image = state.image {
							image.appIconStyle(size: 111, isCircle: false)
						} else {
							Image("App_Unknown").appIconStyle(size: 111, isCircle: false)
						}
					}

					VStack(alignment: .leading, spacing: 2) {
						Text(repository.name)
							.font(.title2)
							.fontWeight(.semibold)
							.foregroundColor(.primary)
						Text(_info?.description ?? repository.owner)
							.font(.subheadline)
							.foregroundColor(.secondary)

						Spacer()

						if let latest = _latest {
							GitHubGetButton(repository: repository, release: latest)
						} else if _isLoading {
							ProgressView()
						}
					}
					.lineLimit(2)
					.frame(maxWidth: .infinity, alignment: .leading)
				}

				Divider()
				_infoPills()
				Divider()

				if let error = _error {
					VStack(alignment: .leading, spacing: 8) {
						Text(error)
							.font(.subheadline)
							.foregroundStyle(.red)
						Button("Try Again") { Task { await _load() } }
					}
					Divider()
				}

				if let latest = _latest {
					NBSection(.localized("What's New")) {
						AppVersionInfo(
							version: latest.displayVersion,
							date: latest.publishedDate,
							description: latest.body?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "No release notes."
						)
						if _releases.count > 1 {
							NavigationLink {
								GitHubVersionHistoryView(repository: repository, releases: _releases)
							} label: {
								Text(.localized("Version History"))
							}
						}
					}
					Divider()
				}

				NBSection(.localized("Information")) {
					VStack(spacing: 12) {
						_infoRow(title: "Repository", value: repository.slug)
						_infoRow(title: .localized("Developer"), value: _info?.owner?.login ?? repository.owner)
						if let latest = _latest {
							_infoRow(title: .localized("Version"), value: latest.tag_name)
							if let date = latest.publishedDate {
								_infoRow(title: .localized("Updated"), value: DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none))
							}
							if let size = latest.ipaAssets.first?.size {
								_infoRow(title: .localized("Size"), value: ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
							}
						}
						if let stars = _info?.stargazers_count {
							_infoRow(title: "Stars", value: stars.formatted())
						}
						if let license = _info?.license?.spdx_id ?? _info?.license?.name, license != "NOASSERTION" {
							_infoRow(title: "License", value: license)
						}
						_infoRow(title: "Releases", value: "\(_releases.count)")
					}
				}
			}
			.padding([.horizontal, .bottom])
		}
		.navigationTitle(repository.name)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			NBToolbarButton(
				systemImage: "safari",
				placement: .topBarTrailing
			) {
				UIApplication.open(_info?.html_url ?? URL(string: "https://github.com/\(repository.slug)")!)
			}
		}
		.refreshable { await _load() }
		.task { await _load() }
	}
}

// MARK: - Extension: View
extension GitHubSourceDetailView {
	private func _infoPills() -> some View {
		var pills: [NBPillItem] = []
		if let latest = _latest {
			pills.append(NBPillItem(title: latest.tag_name, icon: "tag", color: .accentColor))
			if latest.prerelease {
				pills.append(NBPillItem(title: "Pre-release", icon: "flask", color: .orange))
			}
		}
		if let stars = _info?.stargazers_count {
			pills.append(NBPillItem(title: stars.formatted(.number.notation(.compactName)), icon: "star", color: .yellow))
		}
		if let size = _latest?.ipaAssets.first?.size {
			pills.append(NBPillItem(title: ByteCountFormatter.string(fromByteCount: size, countStyle: .file), icon: "archivebox", color: .secondary))
		}
		if pills.isEmpty {
			pills.append(NBPillItem(title: repository.slug, icon: "chevron.left.forwardslash.chevron.right", color: .secondary))
		}
		return HStack(spacing: 6) {
			ForEach(pills.indices, id: \.self) { index in
				NBPillView(title: pills[index].title, icon: pills[index].icon, color: pills[index].color, index: index, count: pills.count)
			}
		}
	}

	@ViewBuilder
	private func _infoRow(title: String, value: String) -> some View {
		LabeledContent(title, value: value)
		Divider()
	}

	private func _load() async {
		_isLoading = true
		_error = nil
		defer { _isLoading = false }
		async let info = try? GitHubRepositoryInfo.fetch(repository)
		do {
			let found = try await GitHubReleases.shared.releases(repository)
			_releases = found
			if found.isEmpty { _error = ReleaseError.noIPA.localizedDescription }
		} catch {
			_error = error.localizedDescription
		}
		_info = await info
	}
}

// MARK: - Version history
struct GitHubVersionHistoryView: View {
	let repository: GitHubRepository
	let releases: [GitHubRelease]

	var body: some View {
		List {
			ForEach(releases.sorted { ($0.published_at ?? "") > ($1.published_at ?? "") }) { release in
				Section {
					VStack(alignment: .leading, spacing: 8) {
						HStack(alignment: .center) {
							VStack(alignment: .leading, spacing: 2) {
								HStack(spacing: 6) {
									Text(release.displayVersion)
										.font(.headline)
									if release.prerelease {
										Text("Pre-release")
											.font(.caption2.bold())
											.foregroundStyle(.orange)
											.padding(.horizontal, 6)
											.padding(.vertical, 2)
											.background(Color.orange.opacity(0.15))
											.clipShape(Capsule())
									}
								}
								if let date = release.publishedDate {
									Text(date.formatted(.relative(presentation: .named)))
										.font(.subheadline)
										.foregroundStyle(.secondary)
								}
							}
							Spacer()
							GitHubGetButton(repository: repository, release: release)
						}
						if let body = release.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
							ExpandableText(text: body, lineLimit: 3)
						}
					}
					.padding(.vertical, 4)
				}
			}
		}
		.navigationTitle(.localized("Version History"))
		.navigationBarTitleDisplayMode(.large)
	}
}

// MARK: - Get button
/// Same look as the AltStore source "Get" button. Imports the release's IPA into the Library, ready to sign and install.
struct GitHubGetButton: View {
	let repository: GitHubRepository
	let release: GitHubRelease

	@ObservedObject private var _releases = GitHubReleases.shared
	@State private var _isWorking = false
	@State private var _isDone = false

	private var _isBusy: Bool { _isWorking || _releases.busy.contains(repository.slug) }

	var body: some View {
		ZStack {
			if _isBusy {
				ProgressView()
					.frame(width: 31, height: 31)
					.compatTransition()
			} else if release.ipaAssets.count > 1 {
				Menu {
					ForEach(release.ipaAssets) { asset in
						Button {
							_get(asset)
						} label: {
							if let size = asset.size {
								Text("\(asset.name) · \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
							} else {
								Text(asset.name)
							}
						}
					}
				} label: {
					_label
				}
				.compatTransition()
			} else if let asset = release.ipaAssets.first {
				Button { _get(asset) } label: { _label }
					.buttonStyle(.borderless)
					.compatTransition()
			}
		}
		.animation(.easeInOut(duration: 0.3), value: _isBusy)
		.animation(.easeInOut(duration: 0.3), value: _isDone)
	}

	private var _label: some View {
		Group {
			if _isDone {
				Image(systemName: "checkmark")
					.font(.headline.bold())
					.padding(.horizontal, 6)
			} else {
				Text(.localized("Get"))
					.font(.headline.bold())
			}
		}
		.lineLimit(0)
		.foregroundStyle(Color.accentColor)
		.padding(.horizontal, 24)
		.padding(.vertical, 6)
		.background(Color(uiColor: .quaternarySystemFill))
		.clipShape(Capsule())
	}

	private func _get(_ asset: GitHubAsset) {
		_isWorking = true
		Task {
			defer { _isWorking = false }
			do {
				_ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
				try await GitHubReleases.shared.importAsset(GitHubTracking(repository: repository, release: release, asset: asset, notifications: true))
				GitHubReleases.schedule()
				UINotificationFeedbackGenerator().notificationOccurred(.success)
				_isDone = true
			} catch {
				UIAlertController.showAlertWithOk(title: .localized("Error"), message: error.localizedDescription)
			}
		}
	}
}

private extension String {
	var nilIfEmpty: String? { isEmpty ? nil : self }
}

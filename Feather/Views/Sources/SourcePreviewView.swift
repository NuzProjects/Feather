import SwiftUI
import AltSourceKit
import NimbleViews
import NukeUI

// MARK: - View
struct SourcePreviewView: View {
	let url: URL
	let repository: ASRepository

	@State private var _isAdded = false
	@State private var _isAdding = false
	@State private var _search = ""

	private var _apps: [ASRepository.App] {
		repository.apps.filter { _search.isEmpty || $0.currentName.localizedCaseInsensitiveContains(_search) }
	}

	// MARK: Body
	var body: some View {
		List {
			Section {
				VStack(alignment: .leading, spacing: 12) {
					HStack(spacing: 14) {
						LazyImage(url: repository.currentIconURL) { state in
							if let image = state.image {
								image.appIconStyle(size: 72, isCircle: false)
							} else {
								Image("App_Unknown").appIconStyle(size: 72, isCircle: false)
							}
						}
						VStack(alignment: .leading, spacing: 4) {
							Text(repository.name ?? .localized("Unknown"))
								.font(.title3.bold())
								.lineLimit(2)
							Text(url.host ?? url.absoluteString)
								.font(.subheadline)
								.foregroundStyle(.secondary)
								.lineLimit(1)
							_addButton
								.padding(.top, 2)
						}
						.frame(maxWidth: .infinity, alignment: .leading)
					}

					if let text = repository.subtitle ?? repository.description, !text.isEmpty {
						ExpandableText(text: text, lineLimit: 3)
							.font(.subheadline)
					}

					_pills()
				}
				.padding(.vertical, 4)
			}

			NBSection(.localized("Apps"), secondary: "\(repository.apps.count)") {
				if _apps.isEmpty {
					Text(repository.apps.isEmpty ? "This source has no apps." : "No matching apps.")
						.foregroundStyle(.secondary)
				}
				ForEach(_apps, id: \.currentUniqueId) { app in
					NavigationLink {
						SourceAppsDetailView(sourceURL: url, source: repository, app: app)
					} label: {
						SourceAppsCellView(sourceURL: url, source: repository, app: app)
					}
				}
			}
		}
		.navigationTitle(repository.name ?? .localized("Source"))
		.nbSoftTopEdge()
		.navigationBarTitleDisplayMode(.inline)
		.searchable(text: $_search, prompt: "Search apps")
		.onAppear {
			_isAdded = Storage.shared.sourceExists(repository.id ?? url.absoluteString)
		}
	}
}

// MARK: - Extension: View
extension SourcePreviewView {
	private var _addButton: some View {
		Button {
			guard !_isAdded, !_isAdding else { return }
			_isAdding = true
			Storage.shared.addSource(url, repository: repository) { _ in
				_isAdding = false
				_isAdded = true
				UINotificationFeedbackGenerator().notificationOccurred(.success)
			}
		} label: {
			Group {
				if _isAdding {
					ProgressView()
				} else if _isAdded {
					Label("Added", systemImage: "checkmark")
				} else {
					Text(.localized("Add"))
				}
			}
			.font(.headline.bold())
			.foregroundStyle(Color.accentColor)
			.padding(.horizontal, 20)
			.padding(.vertical, 6)
			.background(Color(uiColor: .quaternarySystemFill))
			.clipShape(Capsule())
		}
		.buttonStyle(.borderless)
		.disabled(_isAdded)
		.animation(.easeInOut(duration: 0.25), value: _isAdded)
		.animation(.easeInOut(duration: 0.25), value: _isAdding)
	}

	private func _pills() -> some View {
		var pills: [NBPillItem] = [
			NBPillItem(title: repository.apps.count == 1 ? "1 app" : "\(repository.apps.count) apps", icon: "app.badge", color: .accentColor)
		]
		if let news = repository.news, !news.isEmpty {
			pills.append(NBPillItem(title: news.count == 1 ? "1 news post" : "\(news.count) news posts", icon: "newspaper", color: .secondary))
		}
		if let website = repository.website?.host {
			pills.append(NBPillItem(title: website, icon: "safari", color: .secondary))
		}
		return HStack(spacing: 6) {
			ForEach(pills.indices, id: \.self) { index in
				NBPillView(title: pills[index].title, icon: pills[index].icon, color: pills[index].color, index: index, count: pills.count)
			}
		}
	}
}

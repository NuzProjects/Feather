import SwiftUI

@MainActor
enum WhatsNew {
	struct Item: Identifiable {
		let icon: String
		let title: String
		let detail: String
		var id: String { title }
	}

	static let features: [Item] = [
		Item(icon: "arrow.down.app", title: "Straight to the Install Prompt", detail: "Semi Local installs and updates go directly to iOS's install prompt, with no Safari page first."),
		Item(icon: "timer", title: "Signing Time Estimate", detail: "The signing card shows about how long is left, based on how fast your device signed before."),
		Item(icon: "arrow.down.right.and.arrow.up.left", title: "Smaller Apps", detail: "New signing options remove the Apple Watch app and unused languages."),
		Item(icon: "globe", title: "Translated Widgets", detail: "Widgets, Live Activities and progress messages are translated into 13 languages.")
	]

	static let fixes: [Item] = [
		Item(icon: "checkmark.seal", title: "Certificate Names", detail: "Certificates show their team name and team ID instead of a long device ID."),
		Item(icon: "arrow.clockwise", title: "More Reliable Updates", detail: "Feather retries when GitHub has a brief hiccup, and updates always show the install prompt."),
		Item(icon: "app", title: "Install Sheet", detail: "Back to Feather's original look, and progress panels use the same glass as the tab bar.")
	]

	private static let seenKey = "WhatsNew.seenVersion"

	static var version: String { FeatherUpdater.shared.currentVersion }

	static var shouldShow: Bool {
		!version.localizedCaseInsensitiveContains("beta") && UserDefaults.standard.string(forKey: seenKey) != version
	}

	static func markSeen() {
		UserDefaults.standard.set(version, forKey: seenKey)
	}
}

struct WhatsNewView: View {
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		VStack(spacing: 0) {
			ScrollView {
				VStack(alignment: .leading, spacing: 26) {
					VStack(alignment: .leading, spacing: 6) {
						Text("What's New")
							.font(.largeTitle.bold())
						Text("Feather \(WhatsNew.version)")
							.font(.title3)
							.foregroundStyle(.secondary)
					}
					.padding(.top, 36)

					if !WhatsNew.features.isEmpty {
						group("New Features", WhatsNew.features)
					}
					if !WhatsNew.fixes.isEmpty {
						group("Bug Fixes", WhatsNew.fixes)
					}
				}
				.padding(.horizontal, 28)
				.padding(.bottom, 24)
			}

			Button {
				dismiss()
			} label: {
				Text("Continue")
					.font(.headline)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 6)
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.large)
			.padding(.horizontal, 28)
			.padding(.bottom, 20)
		}
		.onDisappear { WhatsNew.markSeen() }
	}

	private func group(_ title: String, _ items: [WhatsNew.Item]) -> some View {
		VStack(alignment: .leading, spacing: 18) {
			Text(title)
				.font(.title3.bold())
				.foregroundStyle(.primary)
			ForEach(items) { item in
				HStack(alignment: .top, spacing: 16) {
					Image(systemName: item.icon)
						.font(.title2)
						.foregroundStyle(Color.accentColor)
						.frame(width: 34)
					VStack(alignment: .leading, spacing: 3) {
						Text(item.title).font(.headline)
						Text(item.detail)
							.font(.subheadline)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
			}
		}
	}
}

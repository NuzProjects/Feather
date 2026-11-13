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
		Item(icon: "person.crop.circle.badge.plus", title: "Sign In with Apple ID", detail: "No certificate? Sign in with a free Apple ID in Certificates and sign apps with it. Apps signed this way last 7 days."),
		Item(icon: "globe.desk", title: "GitHub Sources", detail: "GitHub repositories in Sources show their icon, name and when they last released, just like other sources."),
		Item(icon: "ipad.landscape", title: "Better on iPad", detail: "Settings, app pages and lists keep to a comfortable width, and progress panels fit the iPad's layout."),
		Item(icon: "bolt", title: "Instant Sources", detail: "Sources open right away, even offline, and refresh in the background."),
		Item(icon: "lock.rectangle", title: "Lock Screen Widgets", detail: "See how many days are left on your certificate right from the Lock Screen."),
		Item(icon: "exclamationmark.shield", title: "Install Check", detail: "Feather warns you before installing an app whose certificate has expired or been revoked."),
		Item(icon: "signature", title: "Signing in the Background", detail: "Signing keeps going when you leave Feather, and a notification tells you when it's done.")
	]

	static let fixes: [Item] = [
		Item(icon: "exclamationmark.bubble", title: "Clearer Errors", detail: "GitHub and download errors explain what went wrong in plain words."),
		Item(icon: "globe", title: "Fully Translated", detail: "Every screen is translated into all 13 languages."),
		Item(icon: "internaldrive", title: "Automatic Cleanup", detail: "Leftover files from signing and installing are cleared after a day.")
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
							.foregroundStyle(Color(uiColor: .secondaryLabel))
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
							.foregroundStyle(Color(uiColor: .secondaryLabel))
							.fixedSize(horizontal: false, vertical: true)
					}
				}
			}
		}
	}
}

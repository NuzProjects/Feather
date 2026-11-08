import SwiftUI

struct UpdatePromptView: View {
	let release: GitHubRelease
	let notes: String?
	let onUpdate: () -> Void
	let onLater: () -> Void

	var body: some View {
		VStack(spacing: 0) {
			ScrollView {
				VStack(alignment: .leading, spacing: 24) {
					VStack(alignment: .leading, spacing: 6) {
						Text("Update Available")
							.font(.largeTitle.bold())
						Text(verbatim: "Feather \(FeatherUpdater.displayName(release))")
							.font(.title3)
							.foregroundStyle(.secondary)
					}
					.padding(.top, 36)

					if let notes {
						VStack(alignment: .leading, spacing: 12) {
							Text("What's New")
								.font(.title3.bold())
							Text(LocalizedStringKey(notes))
								.font(.body)
								.foregroundStyle(.secondary)
								.fixedSize(horizontal: false, vertical: true)
						}
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(.horizontal, 28)
				.padding(.bottom, 24)
			}

			VStack(spacing: 8) {
				Button(action: onUpdate) {
					Text("Update")
						.font(.headline)
						.frame(maxWidth: .infinity)
						.padding(.vertical, 6)
				}
				.buttonStyle(.borderedProminent)
				.controlSize(.large)

				Button("Later", action: onLater)
					.controlSize(.large)
			}
			.padding(.horizontal, 28)
			.padding(.bottom, 20)
		}
	}
}

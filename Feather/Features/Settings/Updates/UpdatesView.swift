import SwiftUI
import NimbleViews

struct UpdatesView: View {
	@ObservedObject private var updater = FeatherUpdater.shared
	@State private var alert: String?
	@State private var showWhatsNew = false
	@State private var confirmingBetas = false

	var body: some View {
		NBList(.localized("Updates")) {
			Section {
				LabeledContent("Current Version", value: updater.currentVersion)
				if let latest = updater.latest {
					LabeledContent("Latest Release") {
						Text(FeatherUpdater.displayName(latest))
							.contentTransition(.numericText())
					}
					if let date = latest.published_at.flatMap(ISO8601DateFormatter().date(from:)) {
						LabeledContent("Published") {
							Text(date.formatted(date: .abbreviated, time: .shortened))
								.contentTransition(.numericText())
						}
					}
				}
			}
			.animation(.smooth(duration: 0.35), value: updater.latest?.id)

			NBSection(.localized("What's New")) {
				if updater.updateAvailable, let notes = updater.releaseNotes {
					Text(LocalizedStringKey(notes))
						.font(.subheadline)
						.frame(maxWidth: .infinity, alignment: .leading)
						.id(updater.latest?.id)
						.transition(.opacity)
				}
				Button("What's New in This Version", systemImage: "sparkles") { showWhatsNew = true }
			}
			.animation(.smooth(duration: 0.35), value: updater.latest?.id)

			Section {
				Toggle(isOn: Binding(
					get: { updater.receiveBetas },
					set: { on in
						if on { confirmingBetas = true } else { updater.receiveBetas = false }
					}
				)) {
					Label("Receive Beta Updates", systemImage: "flask")
				}
				.alert("Receive Beta Updates?", isPresented: $confirmingBetas) {
					Button("Turn On") { updater.receiveBetas = true }
					Button("Cancel", role: .cancel) {}
				} message: {
					Text("Betas get new features first but may have bugs or crash. You can turn this off at any time, and Feather will wait for the next full release.")
				}
				Button {
					updater.install()
				} label: {
					HStack {
						Label(_installTitle, systemImage: "arrow.down.circle")
							.contentTransition(.numericText())
							.animation(.smooth(duration: 0.35), value: _installTitle)
						Spacer()
						if updater.phase == .downloading || updater.phase == .signing { ProgressView() }
					}
				}

				Button {
					guard !updater.isBusy else { return }
					Task {
						await updater.check()
						if updater.phase == .idle { alert = updater.updateAvailable ? .localized("A new version of Feather is available.") : .localized("Feather is up to date.") }
					}
				} label: {
					HStack {
						Label("Check for Updates", systemImage: "arrow.clockwise")
						Spacer()
						if updater.phase == .checking { ProgressView() }
					}
				}
			} footer: {
				Text("Feather downloads the newest build from GitHub, signs it with your selected certificate and installs it over this copy. Your apps, sources and settings are kept. Beta updates get new features first but may have bugs.")
			}
		}
		.symbolVariant(.fill)
		.task { if updater.latest == nil { await updater.check() } }
		.onChange(of: updater.phase) { phase in
			if case .failed(let message) = phase { alert = message }
		}
		.sheet(isPresented: $showWhatsNew) {
			WhatsNewView()
				.presentationDetents([.medium, .large])
				.presentationDragIndicator(.visible)
		}
		.alert("Updates", isPresented: Binding(get: { alert != nil }, set: { if !$0 { alert = nil } })) {
			Button("OK") { alert = nil }
		} message: {
			Text(alert ?? "")
		}
	}

	private var _installTitle: String {
		if updater.updateAvailable { return .localized("Download and Install Update") }
		if let latest = updater.latest, FeatherUpdater.displayName(latest) != updater.currentVersion {
			return .localized("Install %@", arguments: FeatherUpdater.displayName(latest))
		}
		return .localized("Reinstall Latest Release")
	}
}

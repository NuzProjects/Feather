import SwiftUI

struct UpdatePromptView: View {
	let release: GitHubRelease
	let notes: String?
	let onUpdate: () -> Void
	let onLater: () -> Void

	private struct NotesSection: Identifiable {
		let id: Int
		let title: String?
		var items: [String]

		var icon: String {
			let name = (title ?? "").lowercased()
			if name.contains("secur") { return "lock.shield" }
			if name.contains("fix") || name.contains("bug") { return "wrench.and.screwdriver" }
			if name.contains("feature") || name.contains("new") { return "sparkles" }
			return "checkmark.circle"
		}
	}

	private var _sections: [NotesSection] {
		guard let notes else { return [] }
		var sections: [NotesSection] = []
		for raw in notes.components(separatedBy: .newlines) {
			let line = raw.trimmingCharacters(in: .whitespaces)
			guard !line.isEmpty else { continue }
			if line.hasPrefix("**"), line.hasSuffix("**") {
				let title = line
					.replacingOccurrences(of: "**", with: "")
					.trimmingCharacters(in: CharacterSet(charactersIn: ": "))
				sections.append(NotesSection(id: sections.count, title: title, items: []))
				continue
			}
			let item = line.hasPrefix("• ") ? String(line.dropFirst(2)) : line
			if sections.isEmpty {
				sections.append(NotesSection(id: 0, title: nil, items: []))
			}
			sections[sections.count - 1].items.append(item)
		}
		return sections.filter { !$0.items.isEmpty }
	}

	var body: some View {
		VStack(spacing: 0) {
			ScrollView {
				VStack(alignment: .leading, spacing: 26) {
					VStack(alignment: .leading, spacing: 6) {
						Text("Update Available")
							.font(.largeTitle.bold())
						Text(verbatim: "Feather \(FeatherUpdater.displayName(release))")
							.font(.title3)
							.foregroundStyle(Color(uiColor: .secondaryLabel))
					}
					.padding(.top, 36)

					ForEach(_sections) { section in
						_group(section)
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

				Button(action: onLater) {
					Text("Later")
						.font(.headline)
						.frame(maxWidth: .infinity)
						.padding(.vertical, 6)
				}
				.buttonStyle(.borderless)
				.controlSize(.large)
			}
			.padding(.horizontal, 28)
			.padding(.bottom, 20)
		}
	}

	private func _group(_ section: NotesSection) -> some View {
		VStack(alignment: .leading, spacing: 18) {
			if let title = section.title {
				Text(verbatim: title)
					.font(.title3.bold())
					.foregroundStyle(.primary)
			}
			ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
				HStack(alignment: .top, spacing: 16) {
					Image(systemName: section.icon)
						.font(.title3)
						.foregroundStyle(Color.accentColor)
						.frame(width: 34)
					Text(LocalizedStringKey(item))
						.font(.subheadline)
						.foregroundStyle(Color(uiColor: .secondaryLabel))
						.fixedSize(horizontal: false, vertical: true)
						.frame(maxWidth: .infinity, alignment: .leading)
				}
			}
		}
	}
}

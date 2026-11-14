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

	private var _cardRadius: CGFloat {
		if #available(iOS 26.0, *) { return 28 }
		return 10.5
	}

	var body: some View {
		VStack(spacing: 0) {
			ScrollView {
				VStack(spacing: 22) {
					_header()
					ForEach(_sections) { section in
						_card(section)
					}
				}
				.frame(maxWidth: .infinity)
				.padding(.horizontal, 20)
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
			.padding(.horizontal, 20)
			.padding(.bottom, 20)
		}
	}

	private func _header() -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Text("Update Available")
				.font(.largeTitle.bold())
			Text(verbatim: "Feather \(FeatherUpdater.displayName(release))")
				.font(.title3.weight(.semibold))
				.foregroundStyle(Color.accentColor)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.horizontal, 4)
		.padding(.top, 36)
	}

	private func _card(_ section: NotesSection) -> some View {
		VStack(alignment: .leading, spacing: 14) {
			if let title = section.title {
				Text(verbatim: title)
					.font(.headline)
					.foregroundStyle(.primary)
			}
			ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
				HStack(alignment: .top, spacing: 12) {
					Image(systemName: section.icon)
						.font(.body.weight(.semibold))
						.foregroundStyle(Color.accentColor)
						.frame(width: 24)
					Text(LocalizedStringKey(item))
						.font(.subheadline)
						.foregroundStyle(Color(uiColor: .secondaryLabel))
						.fixedSize(horizontal: false, vertical: true)
						.frame(maxWidth: .infinity, alignment: .leading)
				}
			}
		}
		.padding(16)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			RoundedRectangle(cornerRadius: _cardRadius, style: .continuous)
				.fill(Color(uiColor: .quaternarySystemFill))
		)
	}
}

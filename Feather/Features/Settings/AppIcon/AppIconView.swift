import SwiftUI
import NimbleViews

extension AppIconView {
	struct AltIcon: Identifiable {
		var displayName: String
		var author: String
		var key: String?
		var image: UIImage
		var id: String { key ?? displayName }

		init(displayName: String, author: String, key: String? = nil) {
			self.displayName = displayName
			self.author = author
			self.key = key
			self.image = altImage(key)
		}
	}

	static func altImage(_ name: String?) -> UIImage {
		let path = Bundle.main.bundleURL.appendingPathComponent((name ?? "AppIcon60x60") + "@2x.png")
		return UIImage(contentsOfFile: path.path) ?? UIImage()
	}
}

struct AppIconView: View {
	@Binding var currentIcon: String?

	var sections: [String: [AltIcon]] = [
		"Main": [
			AltIcon(displayName: "Quill", author: "Samara", key: nil),
			AltIcon(displayName: "Quill (macOS)", author: "Samara", key: "V2Mac"),
			AltIcon(displayName: "Quill v1", author: "Samara", key: "V1"),
			AltIcon(displayName: "Quill v1 (macOS)", author: "Samara", key: "V1Mac"),
			AltIcon(displayName: "Quill v0", author: "Samara", key: "V0"),
			AltIcon(displayName: "Quill Donor", author: "Samara", key: "Donor")
		],
		"Wingio": [
			AltIcon(displayName: "Quill", author: "Wingio", key: "Wing"),
		]
	]

	var body: some View {
		NBList(.localized("App Icon")) {
			ForEach(sections.keys.sorted(), id: \.self) { section in
				if let icons = sections[section] {
					NBSection(section) {
						ForEach(icons) { icon in
							_icon(icon: icon)
						}
					}
				}
			}
		}
		.onAppear {
			currentIcon = UIApplication.shared.alternateIconName
		}
	}
}

extension AppIconView {
	@ViewBuilder
	private func _icon(
		icon: AppIconView.AltIcon
	) -> some View {
		Button {
			UIApplication.shared.setAlternateIconName(icon.key) { error in
				DispatchQueue.main.async {
					withAnimation(.snappy) { currentIcon = error == nil ? icon.key : UIApplication.shared.alternateIconName }
				}
			}
		} label: {
			HStack(spacing: 18) {
				Image(uiImage: icon.image)
					.appIconStyle()

				NBTitleWithSubtitleView(
					title: icon.displayName,
					subtitle: icon.author,
					linelimit: 0
				)

				if currentIcon == icon.key {
					Image(systemName: "checkmark").bold().transition(.scale.combined(with: .opacity))
				}
			}
		}
	}
}

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
        Item(icon: "checkmark.seal", title: "Get a Certificate", detail: "No certificate yet? Tap Get a Certificate in Settings to see where to get one, or import the one you have."),
        Item(icon: "square.grid.2x2", title: "Source Apps on iOS 16", detail: "Tapping an app in a source opens its page on iOS 16 too.")
    ]

    static let fixes: [Item] = [
        Item(icon: "exclamationmark.shield", title: "Fewer Crashes", detail: "Fixed crashes when installing or exporting apps without a version, signing apps with a broken Info.plist, reading some .deb tweaks, and showing alerts in the background."),
        Item(icon: "battery.75percent", title: "Installs Use Less Battery", detail: "Install progress is checked a few times a second instead of a thousand."),
        Item(icon: "arrow.down.circle", title: "Downloads", detail: "Failed downloads now tell you why, broken links are caught, and downloads keep going in the background on iOS 26."),
        Item(icon: "checkmark.seal", title: "Certificates", detail: "Importing a certificate shows an error instead of closing silently when something is wrong."),
        Item(icon: "globe.desk", title: "Sources", detail: "Featured sources all show up, Import tells you when the clipboard is empty, and a source that can't load says so instead of spinning."),
        Item(icon: "puzzlepiece.extension", title: "Tweaks", detail: "Retrying a sign keeps your .dylib tweaks, and .deb files from more tools are read correctly.")
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

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
        Item(icon: "square.grid.2x2", title: "Home Screen Widgets", detail: "A Certificate widget with days left and status, and a Library widget with your recently signed apps, in small and medium."),
        Item(icon: "livephoto", title: "Live Activities", detail: "Signing, downloads and updates show their progress on the Lock Screen and in the Dynamic Island."),
        Item(icon: "exclamationmark.shield", title: "Signing Checks", detail: "Feather warns you before signing an app that's still App Store encrypted or needs a newer iOS."),
        Item(icon: "wifi.slash", title: "Offline Indicator", detail: "A small glass pill above the tab bar shows when you're offline."),
        Item(icon: "globe", title: "13 Languages", detail: "New screens, alerts and errors are translated."),
        Item(icon: "ladybug", title: "Report on GitHub", detail: "After a crash, open a bug report with the details already filled in.")
    ]

    static let fixes: [Item] = [
        Item(icon: "gearshape", title: "Tidier Settings", detail: "App Icon and Navigator are inside Appearance, which is now under Features, and export options are in Signing Options."),
        Item(icon: "puzzlepiece.extension", title: "App Extensions", detail: "Widgets and share sheets inside apps you sign get a signing profile, so they can open."),
        Item(icon: "rectangle.topthird.inset.filled", title: "Top Bar", detail: "No divider line at the top of pages. Content blurs under the bar when you scroll.")
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

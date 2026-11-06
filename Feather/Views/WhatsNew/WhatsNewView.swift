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
        Item(icon: "square.stack.3d.down.forward", title: "Softer Scrolling", detail: "Every page blurs content as it scrolls under the top bar, like the Settings app."),
        Item(icon: "text.badge.star", title: "Formatted Release Notes", detail: "Version history and What's New show bold text, links and bullet points.")
    ]

    static let fixes: [Item] = [
        Item(icon: "arrow.down.circle", title: "Download and Install", detail: "Updating without a certificate opens Get a Certificate instead of doing nothing."),
        Item(icon: "xmark.circle", title: "Reset", detail: "Reset confirmations no longer show stray numbers. Network Cache still shows its size."),
        Item(icon: "plus.circle", title: "Get a Certificate", detail: "A new icon, and third-party sellers are listed as Unofficial Providers with their own logos."),
        Item(icon: "flask", title: "Beta Updates", detail: "Turning on Receive Beta Updates asks you to confirm first, and the version and notes change smoothly when you switch."),
        Item(icon: "arrow.counterclockwise", title: "Reset", detail: "Resetting sources, apps, certificates or caches happens right away without restarting. Resetting settings closes Feather cleanly so it opens normally next time.")
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

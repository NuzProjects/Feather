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
        Item(icon: "checkmark.seal", title: "Certificate Overview", detail: "Tap the certificate in Settings to see how long it has left, what it can do, which devices it covers and which apps you signed with it."),
        Item(icon: "person.text.rectangle", title: "Revocation Check", detail: "Check Revocation shows its progress and tells you whether Apple revoked the certificate."),
        Item(icon: "ladybug", title: "Developer Logs", detail: "Crash reports and errors in Settings → Misc. Export them or save them to Files when you report a bug."),
        Item(icon: "globe.desk", title: "Source Preview", detail: "Tap a featured source in Add Source to browse its apps before adding it."),
        Item(icon: "arrow.down.app", title: "Smoother Updates", detail: "The update popup opens Settings → Updates, and one progress bar covers signing and installing."),
        Item(icon: "chevron.left.forwardslash.chevron.right", title: "GitHub in Settings", detail: "Star Feather, report an issue or open About right from Settings."),
        Item(icon: "dock.rectangle", title: "Navigator", detail: "A cleaner Navigator icon, and the tab bar animates when showing or hiding labels.")
    ]

    static let fixes: [Item] = [
        Item(icon: "text.alignleft", title: "Expandable Text", detail: "Descriptions and release notes expand without flashing, and More shows up whenever text is cut off."),
        Item(icon: "link", title: "Links", detail: "GitHub links and the featured source point to this fork, and the \"open an issue\" text is translated again."),
        Item(icon: "textformat.size", title: "What's New", detail: "Larger section titles, and only this version's changes are listed."),
        Item(icon: "app.dashed", title: "Panel Icons", detail: "Signing and download panel icons no longer have a light outline.")
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

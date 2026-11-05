import SwiftUI

@MainActor
enum WhatsNew {
    struct Item: Identifiable {
        let icon: String
        let title: String
        let detail: String
        var id: String { title }
    }

    // Update for every release.
    static let features: [Item] = [
        Item(icon: "externaldrive", title: "Backup & Transfer", detail: "Back up everything, or just certificates, sources and settings, and restore it on any device."),
        Item(icon: "xmark.octagon", title: "Revoked Certificates", detail: "Feather checks your certificates with Apple and tells you when one is revoked."),
        Item(icon: "lock.rotation", title: "SSL Certificate Check", detail: "Feather picks up a renewed Fully Local certificate on launch and offers to switch back."),
        Item(icon: "exclamationmark.bubble", title: "Clearer Signing Errors", detail: "Signing problems are explained in plain words, with what to do next."),
        Item(icon: "clock.badge.exclamationmark", title: "Certificate Warnings", detail: "A notification before your certificate expires."),
        Item(icon: "hand.wave.fill", title: "Welcome Guide", detail: "A quick walkthrough for new installs."),
        Item(icon: "arrow.clockwise", title: "Pull to Refresh", detail: "Pull down in Library to check for app updates."),
        Item(icon: "iphone.radiowaves.left.and.right", title: "Haptics", detail: "Feel when signing finishes, fails or is cancelled."),
        Item(icon: "sparkles", title: "What's New", detail: "This sheet shows what changed after each update.")
    ]

    static let fixes: [Item] = [
        Item(icon: "arrow.down.app", title: "Updating Feather", detail: "Feather goes to the Home Screen after sending the update so iOS can install it."),
        Item(icon: "server.rack", title: "Semi Local by Default", detail: "Installs use Semi Local unless you switch it in Settings → Installation → Server."),
        Item(icon: "lock.trianglebadge.exclamationmark", title: "Expired SSL Certificate", detail: "Fully Local installs now explain when the SSL certificate has expired instead of getting stuck on Ready."),
        Item(icon: "paintpalette", title: "Accent Swipe Actions", detail: "Library swipe buttons and the signing panel match your style."),
        Item(icon: "doc.badge.plus", title: "Importing Files", detail: "Importing certificates, IPAs and other files works again."),
        Item(icon: "arrow.down.app", title: "Feather Updates Itself", detail: "Feather can now sign and install itself, so the updater works."),
        Item(icon: "signature", title: "Signing Feather", detail: "Apps with extensions, like Feather itself, now sign with certificates made for one app."),
        Item(icon: "text.alignleft", title: "Update Popup", detail: "Release notes in the update popup are now clean text."),
        Item(icon: "app.badge", title: "Updates Badge", detail: "Removed the badge on Settings → Updates.")
    ]

    private static let seenKey = "WhatsNew.seenVersion"

    static var version: String { FeatherUpdater.shared.currentVersion }

    /// Shows automatically only for official releases, not betas.
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

                    group("New Features", WhatsNew.features)
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
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
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

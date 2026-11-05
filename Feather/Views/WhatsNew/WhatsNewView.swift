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
        Item(icon: "hand.wave.fill", title: "Welcome Guide", detail: "A quick walkthrough for new installs.")
    ]

    static let fixes: [Item] = [
        Item(icon: "arrow.down.app", title: "Feather Updates Itself", detail: "Update Feather from Settings → Updates without sideloading it again."),
        Item(icon: "server.rack", title: "Semi Local by Default", detail: "Installs use Semi Local, since the Fully Local SSL certificate expired."),
        Item(icon: "doc.badge.plus", title: "Importing Files", detail: "Importing certificates, IPAs and other files works again."),
        Item(icon: "signature", title: "Signing Apps with Extensions", detail: "Apps like Feather now sign with certificates made for one app.")
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

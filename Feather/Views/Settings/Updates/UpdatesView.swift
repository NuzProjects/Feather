import SwiftUI
import NimbleViews

struct UpdatesView: View {
    @ObservedObject private var updater = FeatherUpdater.shared

    var body: some View {
        NBList("Updates") {
            Section {
                LabeledContent("Current Version", value: updater.currentVersion)
                if let latest = updater.latest {
                    LabeledContent("Latest Release", value: latest.name ?? latest.tag_name)
                    if let date = latest.published_at.flatMap(ISO8601DateFormatter().date(from:)) {
                        LabeledContent("Published", value: date.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            } footer: {
                Text(statusText)
            }

            Section {
                Button {
                    updater.install()
                } label: {
                    HStack {
                        Label(updater.updateAvailable ? "Download and Install Update" : "Reinstall Latest Release", systemImage: "arrow.down.circle")
                        Spacer()
                        if updater.phase == .downloading || updater.phase == .signing { ProgressView() }
                    }
                }
                .disabled(updater.latest == nil || updater.isBusy)

                Button {
                    Task { await updater.check() }
                } label: {
                    HStack {
                        Label("Check for Updates", systemImage: "arrow.clockwise")
                        Spacer()
                        if updater.phase == .checking { ProgressView() }
                    }
                }
                .disabled(updater.isBusy)
            } footer: {
                Text("Feather downloads the newest build from GitHub, signs it with your selected certificate and installs it over this copy. Your apps, sources and settings are kept.")
            }
        }
        .symbolVariant(.fill)
        .task { if updater.latest == nil { await updater.check() } }
        .sheet(item: $updater.signedUpdate) { app in
            InstallPreviewView(app: app.base)
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
        }
    }

    private var statusText: String {
        switch updater.phase {
        case .checking: return "Checking GitHub for a newer version…"
        case .downloading: return "Downloading the update…"
        case .signing: return "Signing the update with your certificate…"
        case .ready: return "The update is signed and ready to install."
        case .failed(let message): return message
        case .idle:
            if updater.latest == nil { return "No releases found yet." }
            return updater.updateAvailable ? "A new version of Feather is available." : "Feather is up to date."
        }
    }
}

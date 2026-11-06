import SwiftUI
import NimbleViews

struct UpdatesView: View {
    @ObservedObject private var updater = FeatherUpdater.shared
    @State private var alert: String?
    @State private var showWhatsNew = false

    var body: some View {
        NBList("Updates") {
            Section {
                LabeledContent("Current Version", value: updater.currentVersion)
                if let latest = updater.latest {
                    LabeledContent("Latest Release", value: FeatherUpdater.displayName(latest))
                    if let date = latest.published_at.flatMap(ISO8601DateFormatter().date(from:)) {
                        LabeledContent("Published", value: date.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }

            NBSection("What's New") {
                if let notes = updater.releaseNotes {
                    Text(LocalizedStringKey(notes))
                        .font(.subheadline)
                }
                Button("What's New in This Version", systemImage: "sparkles") { showWhatsNew = true }
            }

            Section {
                Toggle(isOn: $updater.receiveBetas) {
                    Label("Receive Beta Updates", systemImage: "flask")
                }
                Button {
                    updater.install()
                } label: {
                    HStack {
                        Label(_installTitle, systemImage: "arrow.down.circle")
                        Spacer()
                        if updater.phase == .downloading || updater.phase == .signing { ProgressView() }
                    }
                }

                Button {
                    guard !updater.isBusy else { return }
                    Task {
                        await updater.check()
                        if updater.phase == .idle { alert = updater.updateAvailable ? "A new version of Feather is available." : "Feather is up to date." }
                    }
                } label: {
                    HStack {
                        Label("Check for Updates", systemImage: "arrow.clockwise")
                        Spacer()
                        if updater.phase == .checking { ProgressView() }
                    }
                }
            } footer: {
                Text("Feather downloads the newest build from GitHub, signs it with your selected certificate and installs it over this copy. Your apps, sources and settings are kept. Beta updates get new features first but may have bugs.")
            }
        }
        .symbolVariant(.fill)
        .task { if updater.latest == nil { await updater.check() } }
        .onChange(of: updater.phase) { phase in
            if case .failed(let message) = phase { alert = message }
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Updates", isPresented: Binding(get: { alert != nil }, set: { if !$0 { alert = nil } })) {
            Button("OK") { alert = nil }
        } message: {
            Text(alert ?? "")
        }
    }

    private var _installTitle: String {
        if updater.updateAvailable { return "Download and Install Update" }
        // On a beta with betas turned off, the latest full release is older, so say exactly what gets installed.
        if let latest = updater.latest, FeatherUpdater.displayName(latest) != updater.currentVersion {
            return "Install \(FeatherUpdater.displayName(latest))"
        }
        return "Reinstall Latest Release"
    }
}

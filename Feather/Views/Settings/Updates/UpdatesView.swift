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
                Button("What's New in This Version", systemImage: "sparkles") { showWhatsNew = true }
                if let latest = updater.latest {
                    LabeledContent("Latest Release", value: latest.name ?? latest.tag_name)
                    if let date = latest.published_at.flatMap(ISO8601DateFormatter().date(from:)) {
                        LabeledContent("Published", value: date.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }

            if let notes = updater.releaseNotes {
                NBSection("What's New") {
                    Text(LocalizedStringKey(notes))
                        .font(.subheadline)
                }
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
                .disabled(updater.isBusy)
            } footer: {
                Text("Feather downloads the newest build from GitHub, signs it with your selected certificate and installs it over this copy. Your apps, sources and settings are kept.")
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
}

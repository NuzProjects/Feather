import SwiftUI
import UserNotifications
struct GitHubImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var repository: GitHubRepository?
    @State private var releases: [GitHubRelease] = []
    @State private var busy = false
    @State private var error: String?
    @State private var notify = true
    @State private var offerSource = false
    @State private var prompted: Set<String> = []
    init(repositoryInput: String = "") { _input = State(initialValue: repositoryInput) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Repository") {
                    TextField("owner/repository or GitHub URL", text: $input).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    Button("Find Releases") { Task { await load() } }.disabled(busy || input.isEmpty)
                }
                Section {
                    Toggle("Notify About Updates", isOn: $notify)
                } footer: { Text("Checks run when you open the app and when iOS allows background refresh. Updates install only when you choose Update.") }
                if busy { ProgressView("Working…") }
                if let error { Section { Text(error).foregroundStyle(.red).textSelection(.enabled) } }
                ForEach(releases) { release in
                    Section(release.name ?? release.tag_name) {
                        ForEach(release.ipaAssets) { asset in
                            Button { Task { await importIPA(release, asset) } } label: {
                                Label(asset.name, systemImage: "arrow.down.circle")
                            }.disabled(busy)
                        }
                    }
                }
            }
            .navigationTitle("Import from GitHub")
            .task { if !input.isEmpty { await load() } }
            .alert("Add to Sources?", isPresented: $offerSource) {
                Button("Add to Sources") { if let repository { GitHubSources.shared.add(repository) } }
                Button("Not Now", role: .cancel) {}
            } message: { Text("Keep this GitHub repository in Sources to browse its IPA releases later.") }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(busy) } }
            .interactiveDismissDisabled(busy)
        }
    }
    private func load() async {
        busy = true; error = nil; releases = []; defer { busy = false }
        do {
            let repo = try GitHubRepository(input)
            let found = try await GitHubReleases.shared.releases(repo)
            guard !found.isEmpty else { throw ReleaseError.noIPA }
            repository = repo; releases = found
            if !GitHubSources.shared.repositories.contains(where: { $0.slug.lowercased() == repo.slug.lowercased() }), prompted.insert(repo.slug.lowercased()).inserted { offerSource = true }
        } catch { self.error = error.localizedDescription }
    }
    private func importIPA(_ release: GitHubRelease, _ asset: GitHubAsset) async {
        guard let repository else { return }
        busy = true; error = nil; defer { busy = false }
        do {
            if notify { _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) }
            try await GitHubReleases.shared.importAsset(GitHubTracking(repository: repository, release: release, asset: asset, notifications: notify))
            GitHubReleases.schedule(); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

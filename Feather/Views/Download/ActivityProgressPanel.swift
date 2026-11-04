import SwiftUI

@MainActor
final class ImportProgress: ObservableObject {
    static let shared = ImportProgress()
    struct Job: Identifiable {
        let id: UUID
        var name: String
        var icon: UIImage?
        var fraction: Double
    }
    @Published private(set) var jobs: [Job] = []
    func begin(_ name: String) -> UUID {
        let id = UUID(); jobs.append(Job(id: id, name: name, fraction: 0)); return id
    }
    func update(_ id: UUID?, fraction: Double, name: String? = nil, icon: UIImage? = nil) {
        guard let id, let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].fraction = max(jobs[index].fraction, min(1, max(0, fraction)))
        if let name { jobs[index].name = name }
        if let icon { jobs[index].icon = icon }
    }
    func finish(_ id: UUID?, success: Bool) {
        guard let id else { return }
        if success { update(id, fraction: 1) }
        Task {
            try? await Task.sleep(nanoseconds: success ? 700_000_000 : 0)
            jobs.removeAll { $0.id == id }
        }
    }
}

struct ActivityProgressPanel: View {
    @ObservedObject private var downloads = DownloadManager.shared
    @ObservedObject private var imports = ImportProgress.shared
    var body: some View {
        VStack(spacing: 8) {
            SigningProgressPanel()
            if let download = downloads.downloads.first { DownloadProgressCard(download: download) }
            else if let job = imports.jobs.first { ImportProgressCard(name: job.name, icon: job.icon, fraction: job.fraction) }
        }
    }
}

private struct DownloadProgressCard: View {
    @ObservedObject var download: Download
    var body: some View {
        ImportProgressCard(name: download.displayName ?? download.fileName, icon: download.appIcon, fraction: download.overallProgress)
    }
}

private struct ImportProgressCard: View {
    let name: String
    let icon: UIImage?
    let fraction: Double
    var body: some View {
        surface {
            HStack(spacing: 12) {
                Group {
                    if let icon { Image(uiImage: icon).resizable().scaledToFit() }
                    else { Image(systemName: "doc").font(.title2).frame(maxWidth: .infinity, maxHeight: .infinity).background(.quaternary) }
                }
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Spacer(minLength: 8)
                        Text("\(Int(min(1, max(0, fraction)) * 100))%")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    ProgressView(value: min(1, max(0, fraction))).progressViewStyle(.linear)
                }
            }.padding(14)
        }
        .padding(.horizontal, 12)
        .animation(.smooth(duration: 0.2), value: Int(fraction * 100))
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder private func surface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26, *) { content().glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22)) }
        else { content().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22)) }
    }
}

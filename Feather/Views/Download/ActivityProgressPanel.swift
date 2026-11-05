import SwiftUI
import NukeUI

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
            if let download = downloads.downloads.first { DownloadProgressCard(download: download).transition(.progressPanel) }
            else if let job = imports.jobs.first { ImportProgressCard(name: job.name, icon: job.icon, fraction: job.fraction).transition(.progressPanel) }
        }
        .animation(.smooth(duration: 0.4), value: downloads.downloads.first?.id)
        .animation(.smooth(duration: 0.4), value: imports.jobs.first?.id)
    }
}

extension AnyTransition {
    /// Fades and gently rises in, then fades and sinks out.
    static var progressPanel: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .bottom)).combined(with: .offset(y: 16)),
            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)).combined(with: .offset(y: 10))
        )
    }
}

private struct DownloadProgressCard: View {
    @ObservedObject var download: Download
    var body: some View {
        ImportProgressCard(name: download.displayName ?? download.fileName, icon: download.appIcon, iconURL: download.iconURL, fraction: download.overallProgress)
    }
}

private struct ImportProgressCard: View {
    let name: String
    let icon: UIImage?
    var iconURL: URL? = nil
    let fraction: Double
    var body: some View {
        surface {
            HStack(spacing: 12) {
                iconView
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

private extension ImportProgressCard {
    var iconSize: CGFloat { 42 }
    var iconShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: iconSize * (ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)) ? 0.2677 : 0.2337), style: .continuous)
    }
    @ViewBuilder var iconView: some View {
        Group {
            if let icon { Image(uiImage: icon).resizable().scaledToFill() }
            else if let iconURL {
                LazyImage(url: iconURL) { state in
                    if let image = state.image { image.resizable().scaledToFill() } else { placeholder }
                }
            } else { placeholder }
        }
        .frame(width: iconSize, height: iconSize)
        .clipShape(iconShape)
        .overlay(iconShape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
    }
    var placeholder: some View {
        Image(systemName: "app.fill").font(.title3).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(.quaternary)
    }
}

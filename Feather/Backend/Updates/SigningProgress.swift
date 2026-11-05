import SwiftUI
import UIKit

@MainActor
final class SigningProgress: ObservableObject {
    static let shared = SigningProgress()
    enum Stage: Int {
        case copying, preparing, signing, saving, complete, failed, cancelled
        var title: String {
            switch self {
            case .copying: return "Copying app"
            case .preparing: return "Preparing app"
            case .signing: return "Signing app"
            case .saving: return "Saving signed app"
            case .complete: return "Signing complete"
            case .failed: return "Signing failed"
            case .cancelled: return "Signing cancelled"
            }
        }
        var fraction: Double { self == .failed || self == .cancelled ? 0 : Double(rawValue) / 4 }
        var isActive: Bool { rawValue < Stage.complete.rawValue }
    }
    struct Job: Identifiable {
        let id: UUID
        let name: String
        let icon: UIImage?
        var stage: Stage
    }
    @Published private(set) var jobs: [Job] = []
    private var leases: [UUID: UIBackgroundTaskIdentifier] = [:]
    private var cancelled: Set<UUID> = []
    func begin(name: String, icon: UIImage? = nil) -> UUID {
        let id = UUID()
        jobs.append(Job(id: id, name: name, icon: icon, stage: .copying))
        leases[id] = UIApplication.shared.beginBackgroundTask(withName: "Sign app") { [weak self] in
            Task { @MainActor in self?.endLease(id) }
        }
        return id
    }
    func stage(_ id: UUID?, _ stage: Stage) {
        guard let id, let index = jobs.firstIndex(where: { $0.id == id }), jobs[index].stage.isActive else { return }
        jobs[index].stage = stage
    }
    func cancel(_ id: UUID) {
        guard let job = jobs.first(where: { $0.id == id }), job.stage.isActive else { return }
        cancelled.insert(id)
        stage(id, .cancelled)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        endLease(id)
        remove(id, after: 1_200_000_000)
    }
    func isCancelled(_ id: UUID) -> Bool { cancelled.contains(id) }
    func finish(_ id: UUID, success: Bool) {
        guard !cancelled.contains(id) else { return }
        stage(id, success ? .complete : .failed)
        UINotificationFeedbackGenerator().notificationOccurred(success ? .success : .error)
        endLease(id)
        remove(id, after: success ? 1_500_000_000 : 4_000_000_000)
    }
    private func remove(_ id: UUID, after delay: UInt64) {
        Task {
            try? await Task.sleep(nanoseconds: delay)
            jobs.removeAll { $0.id == id }
            cancelled.remove(id)
        }
    }
    private func endLease(_ id: UUID) {
        guard let lease = leases.removeValue(forKey: id), lease != .invalid else { return }
        UIApplication.shared.endBackgroundTask(lease)
    }
}

struct SigningProgressPanel: View {
    @ObservedObject private var progress = SigningProgress.shared
    @State private var confirming: SigningProgress.Job?
    var body: some View {
        ZStack {
            if let job = progress.jobs.first {
                card(job)
                    .transition(.progressPanel)
                    .onTapGesture { if job.stage.isActive { confirming = job } }
            }
        }
        .animation(.smooth(duration: 0.4), value: progress.jobs.first?.id)
        .confirmationDialog("Cancel signing \(confirming?.name ?? "")?", isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }), titleVisibility: .visible) {
            Button("Cancel Signing", role: .destructive) { if let job = confirming { progress.cancel(job.id) } }
            Button("Keep Signing", role: .cancel) {}
        }
    }
    private func card(_ job: SigningProgress.Job) -> some View {
        surface {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 12) {
                    Group {
                        if let icon = job.icon { Image(uiImage: icon).resizable().scaledToFill() }
                        else { Image("App_Unknown").resizable().scaledToFill() }
                    }
                    .scaleEffect(1.06)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 42 * (ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)) ? 0.2677 : 0.2337), style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(job.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(job.stage.title).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if progress.jobs.count > 1 { Text("+\(progress.jobs.count - 1)").font(.caption.monospacedDigit()) }
                }
                ProgressView(value: job.stage.fraction)
                    .accessibilityLabel(job.stage.title)
            }.padding(16)
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .animation(.smooth, value: job.stage.rawValue)
    }
    @ViewBuilder private func surface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26, *) { content().glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24)) }
        else { content().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12))) }
    }
}

import SwiftUI
import UIKit

@MainActor
final class SigningProgress: ObservableObject {
    static let shared = SigningProgress()
    enum Stage: Int {
        case copying, preparing, signing, saving, complete, failed
        var title: String {
            switch self {
            case .copying: return "Copying app"
            case .preparing: return "Preparing app"
            case .signing: return "Signing app"
            case .saving: return "Saving signed app"
            case .complete: return "Signing complete"
            case .failed: return "Signing failed"
            }
        }
        var fraction: Double { self == .failed ? 0 : Double(rawValue) / 4 }
    }
    struct Job: Identifiable {
        let id: UUID
        let name: String
        var stage: Stage
    }
    @Published private(set) var jobs: [Job] = []
    private var leases: [UUID: UIBackgroundTaskIdentifier] = [:]
    func begin(name: String) -> UUID {
        let id = UUID()
        jobs.append(Job(id: id, name: name, stage: .copying))
        leases[id] = UIApplication.shared.beginBackgroundTask(withName: "Sign app") { [weak self] in
            Task { @MainActor in self?.endLease(id) }
        }
        return id
    }
    func stage(_ id: UUID?, _ stage: Stage) {
        guard let id, let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].stage = stage
    }
    func finish(_ id: UUID, success: Bool) {
        stage(id, success ? .complete : .failed)
        endLease(id)
        Task {
            try? await Task.sleep(nanoseconds: success ? 1_500_000_000 : 4_000_000_000)
            jobs.removeAll { $0.id == id }
        }
    }
    private func endLease(_ id: UUID) {
        guard let lease = leases.removeValue(forKey: id), lease != .invalid else { return }
        UIApplication.shared.endBackgroundTask(lease)
    }
}

struct SigningProgressPanel: View {
    @ObservedObject private var progress = SigningProgress.shared
    var body: some View {
        if let job = progress.jobs.first {
            surface {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 12) {
                        Image(systemName: job.stage == .complete ? "checkmark.seal.fill" : "signature").font(.title3)
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
            .animation(.smooth, value: job.stage.rawValue)
        }
    }
    @ViewBuilder private func surface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26, *) { content().glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24)) }
        else { content().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12))) }
    }
}

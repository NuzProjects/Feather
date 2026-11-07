import SwiftUI
import UIKit
import NukeUI

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
		let isUpdate: Bool
	}
	@Published private(set) var jobs: [Job] = []
	var visibleJobs: [Job] { jobs.filter { !$0.isUpdate } }
	private var leases: [UUID: UIBackgroundTaskIdentifier] = [:]
	private var cancelled: Set<UUID> = []
	func begin(name: String, icon: UIImage? = nil) -> UUID {
		let id = UUID()
		jobs.append(Job(id: id, name: name, icon: icon, stage: .copying, isUpdate: FeatherUpdater.shared.phase == .signing))
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
			if let job = progress.visibleJobs.first {
				card(job)
					.transition(.progressPanel)
					.onTapGesture { if job.stage.isActive { confirming = job } }
			}
		}
		.animation(.smooth(duration: 0.4), value: progress.visibleJobs.first?.id)
		.confirmationDialog("Cancel signing \(confirming?.name ?? "")?", isPresented: _isConfirming, titleVisibility: .visible) {
			Button("Cancel Signing", role: .destructive) { if let job = confirming { progress.cancel(job.id) } }
			Button("Keep Signing", role: .cancel) {}
		}
	}
	private var _isConfirming: Binding<Bool> {
		Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } })
	}

	private func card(_ job: SigningProgress.Job) -> some View {
		ProgressPanelSurface {
			VStack(alignment: .leading, spacing: 9) {
				HStack(spacing: 12) {
					ProgressPanelIcon(image: job.icon)
					VStack(alignment: .leading, spacing: 2) {
						Text(job.name).font(.subheadline.weight(.semibold)).lineLimit(1)
						Text(job.stage.title).font(.caption).foregroundStyle(.secondary)
					}
					Spacer(minLength: 8)
					if progress.visibleJobs.count > 1 { Text("+\(progress.visibleJobs.count - 1)").font(.caption.monospacedDigit()) }
				}
				ProgressView(value: job.stage.fraction)
					.accessibilityLabel(job.stage.title)
			}.padding(16)
		}
		.padding(.horizontal, 12)
		.contentShape(Rectangle())
		.animation(.smooth, value: job.stage.rawValue)
	}
}

struct UpdateProgressPanel: View {
	@ObservedObject private var updater = FeatherUpdater.shared
	@ObservedObject private var signing = SigningProgress.shared
	@ObservedObject private var imports = ImportProgress.shared
	@State private var icon: UIImage?

	private var state: (title: String, fraction: Double)? {
		if updater.signedUpdate != nil {
			return (updater.installLabel ?? "Installing", 0.7 + updater.installFraction * 0.3)
		}
		switch updater.phase {
		case .downloading:
			if let job = imports.jobs.first(where: \.isUpdate) { return ("Preparing update", 0.1 + job.fraction * 0.1) }
			return ("Downloading update", 0.05)
		case .signing:
			let stage = signing.jobs.first(where: \.isUpdate)?.stage
			return (stage?.title ?? "Signing app", 0.2 + (stage?.fraction ?? 0) * 0.5)
		default:
			return nil
		}
	}

	var body: some View {
		ZStack {
			if let state { card(state).transition(.progressPanel) }
		}
		.animation(.smooth(duration: 0.4), value: state != nil)
		.task { icon = await Task.detached { iconTest(Bundle.main.bundleURL) }.value }
	}

	private func card(_ state: (title: String, fraction: Double)) -> some View {
		ProgressPanelSurface {
			VStack(alignment: .leading, spacing: 9) {
				HStack(spacing: 12) {
					ProgressPanelIcon(image: icon)
					VStack(alignment: .leading, spacing: 2) {
						Text("Feather").font(.subheadline.weight(.semibold)).lineLimit(1)
						Text(state.title).font(.caption).foregroundStyle(.secondary)
					}
					Spacer(minLength: 8)
				}
				ProgressView(value: min(1, max(0, state.fraction)))
					.accessibilityLabel(state.title)
			}.padding(16)
		}
		.padding(.horizontal, 12)
		.animation(.smooth, value: state.fraction)
	}
}

struct ProgressPanelIcon: View {
	let image: UIImage?
	var url: URL? = nil
	var body: some View {
		Group {
			if let image { Image(uiImage: image).resizable().scaledToFill() }
			else if let url {
				LazyImage(url: url) { state in
					if let loaded = state.image { loaded.resizable().scaledToFill() } else { placeholder }
				}
			} else { placeholder }
		}
		.scaleEffect(1.06)
		.frame(width: 42, height: 42)
		.clipShape(RoundedRectangle(cornerRadius: 42 * .appIconCornerRatio, style: .continuous))
	}
	private var placeholder: some View {
		Image("App_Unknown").resizable().scaledToFill()
	}
}

struct ProgressPanelSurface<Content: View>: View {
	var cornerRadius: CGFloat = 24
	@ViewBuilder let content: () -> Content
	var body: some View {
		let shape = RoundedRectangle(cornerRadius: cornerRadius)
		if #available(iOS 26, *) {
			content().glassEffect(.clear.tint(Color(uiColor: .systemBackground).opacity(0.25)), in: shape)
		} else {
			content()
				.background(.ultraThinMaterial, in: shape)
				.overlay(shape.stroke(.white.opacity(0.12)))
		}
	}
}

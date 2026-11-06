import Combine
import SwiftUI
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif

@MainActor
final class LiveProgressActivity {
	static let shared = LiveProgressActivity()

	private struct Snapshot: Equatable {
		var title: String
		var detail: String
		var fraction: Double
		var symbol: String
		var others: Int
		var finished: Bool
	}

	private var cancellables: Set<AnyCancellable> = []
	private var timer: Timer?
	private var activity: Any?
	private var lastSent: Snapshot?
	private var lastSentAt = Date.distantPast

	func start() {
		guard cancellables.isEmpty else { return }
		_endStaleActivities()
		let publishers: [AnyPublisher<Void, Never>] = [
			DownloadManager.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
			ImportProgress.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
			SigningProgress.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
			FeatherUpdater.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher()
		]
		Publishers.MergeMany(publishers)
			.receive(on: DispatchQueue.main)
			.sink { [weak self] in self?._wake() }
			.store(in: &cancellables)
	}

	private func _wake() {
		_tick()
		guard timer == nil else { return }
		timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
			Task { @MainActor in self?._tick() }
		}
	}

	private func _tick() {
		guard let snapshot = _snapshot() else {
			timer?.invalidate()
			timer = nil
			_end()
			return
		}
		_show(snapshot)
	}

	private func _snapshot() -> Snapshot? {
		let updater = FeatherUpdater.shared
		let signing = SigningProgress.shared
		let imports = ImportProgress.shared
		let downloads = DownloadManager.shared.downloads

		let signingJobs = signing.visibleJobs
		let importJobs = imports.jobs.filter { !$0.isUpdate }
		let total = signingJobs.count + downloads.count + importJobs.count

		if updater.signedUpdate != nil {
			return Snapshot(title: "Feather", detail: updater.installLabel ?? "Installing", fraction: 0.7 + updater.installFraction * 0.3, symbol: "arrow.triangle.2.circlepath", others: total, finished: false)
		}
		switch updater.phase {
		case .downloading:
			let fraction = imports.jobs.first(where: \.isUpdate).map { 0.1 + $0.fraction * 0.1 } ?? 0.05
			return Snapshot(title: "Feather", detail: "Downloading update", fraction: fraction, symbol: "arrow.triangle.2.circlepath", others: total, finished: false)
		case .signing:
			let stage = signing.jobs.first(where: \.isUpdate)?.stage
			return Snapshot(title: "Feather", detail: stage?.title ?? "Signing app", fraction: 0.2 + (stage?.fraction ?? 0) * 0.5, symbol: "arrow.triangle.2.circlepath", others: total, finished: false)
		default:
			break
		}

		if let job = signingJobs.first {
			let symbol: String
			switch job.stage {
			case .complete: symbol = "checkmark.circle.fill"
			case .failed: symbol = "xmark.circle.fill"
			case .cancelled: symbol = "xmark.circle"
			default: symbol = "signature"
			}
			let fraction = job.stage == .complete ? 1 : job.stage.fraction
			return Snapshot(title: job.name, detail: job.stage.title, fraction: fraction, symbol: symbol, others: total - 1, finished: !job.stage.isActive)
		}
		if let download = downloads.first {
			return Snapshot(title: download.displayName ?? download.fileName, detail: "Downloading", fraction: download.overallProgress, symbol: "arrow.down.circle.fill", others: total - 1, finished: false)
		}
		if let job = importJobs.first {
			return Snapshot(title: job.name, detail: "Importing", fraction: job.fraction, symbol: "square.and.arrow.down.fill", others: total - 1, finished: false)
		}
		return nil
	}

	private func _show(_ snapshot: Snapshot) {
		#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
		guard #available(iOS 16.2, *), ExtensionHealth.extensionsCanRun else { return }
		var rounded = snapshot
		rounded.fraction = (min(1, max(0, snapshot.fraction)) * 100).rounded() / 100
		guard rounded != lastSent else { return }
		let important = rounded.detail != lastSent?.detail || rounded.title != lastSent?.title || rounded.finished
		guard important || Date().timeIntervalSince(lastSentAt) >= 1 else { return }
		lastSent = rounded
		lastSentAt = Date()

		let state = FeatherProgressAttributes.ContentState(
			title: rounded.title,
			detail: rounded.detail,
			fraction: rounded.fraction,
			symbol: rounded.symbol,
			tint: UserDefaults.standard.string(forKey: "Feather.userTintColor") ?? "#848ef9",
			others: max(0, rounded.others),
			finished: rounded.finished
		)
		let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(120))

		if let current = activity as? Activity<FeatherProgressAttributes>, current.activityState == .active {
			Task { await current.update(content) }
			return
		}
		guard ActivityAuthorizationInfo().areActivitiesEnabled else {
			DevLog.shared.log(.info, "Live Activities are turned off for Feather in iOS Settings", category: "Widgets")
			return
		}
		do {
			activity = try Activity.request(attributes: FeatherProgressAttributes(), content: content, pushType: nil)
		} catch {
			DevLog.shared.error(error, while: "Starting the Live Activity", category: "Widgets")
		}
		#endif
	}

	private func _end() {
		#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
		guard #available(iOS 16.2, *) else { return }
		guard let current = activity as? Activity<FeatherProgressAttributes> else { return }
		activity = nil
		let finalState = lastSent
		lastSent = nil
		Task {
			if let finalState {
				let state = FeatherProgressAttributes.ContentState(
					title: finalState.title,
					detail: finalState.detail,
					fraction: finalState.fraction,
					symbol: finalState.symbol,
					tint: UserDefaults.standard.string(forKey: "Feather.userTintColor") ?? "#848ef9",
					others: 0,
					finished: true
				)
				await current.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(4)))
			} else {
				await current.end(nil, dismissalPolicy: .immediate)
			}
		}
		#endif
	}

	private func _endStaleActivities() {
		#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
		guard #available(iOS 16.2, *) else { return }
		for stale in Activity<FeatherProgressAttributes>.activities {
			Task { await stale.end(nil, dismissalPolicy: .immediate) }
		}
		#endif
	}
}

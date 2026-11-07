import Network
import SwiftUI

@MainActor
final class NetworkStatus: ObservableObject {
	static let shared = NetworkStatus()

	@Published private(set) var isOffline = false
	@Published private(set) var hasWiFi = true
	@Published private(set) var hasCellular = true

	private let _monitor = NWPathMonitor()
	private var _pending: Task<Void, Never>?

	private init() {
		_monitor.pathUpdateHandler = { [weak self] path in
			let offline = path.status != .satisfied
			let wifi = path.availableInterfaces.contains { $0.type == .wifi }
			let cellular = path.availableInterfaces.contains { $0.type == .cellular }
			Task { @MainActor in self?._apply(offline: offline, wifi: wifi, cellular: cellular) }
		}
		_monitor.start(queue: DispatchQueue(label: "Feather.NetworkStatus"))
	}

	private func _apply(offline: Bool, wifi: Bool, cellular: Bool) {
		hasWiFi = wifi
		hasCellular = cellular
		_pending?.cancel()
		guard offline != isOffline else { return }
		// Wait a moment so brief drops (switching networks) don't flash the pill.
		_pending = Task { @MainActor in
			try? await Task.sleep(nanoseconds: offline ? 1_200_000_000 : 300_000_000)
			guard !Task.isCancelled else { return }
			isOffline = offline
		}
	}
}

struct OfflinePill: View {
	@ObservedObject private var _status = NetworkStatus.shared
	@Environment(\.accessibilityReduceMotion) private var _reduceMotion

	var body: some View {
		ZStack {
			if _status.isOffline {
				_pill
					.padding(.top, 8)
					.transition(
						_reduceMotion
							? .opacity
							: .asymmetric(
								insertion: .opacity.combined(with: .scale(scale: 0.85, anchor: .bottom)).combined(with: .offset(y: 10)),
								removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)).combined(with: .offset(y: 6))
							)
					)
			}
		}
		.animation(.spring(response: 0.45, dampingFraction: 0.82), value: _status.isOffline)
		.allowsHitTesting(false)
	}

	private var _pill: some View {
		HStack(spacing: 6) {
			Image(systemName: _status.hasWiFi ? "wifi" : "wifi.slash")
				.foregroundStyle(_status.hasWiFi ? Color.primary : Color.secondary.opacity(0.6))
			Image(systemName: _status.hasCellular ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
				.foregroundStyle(_status.hasCellular ? Color.primary : Color.secondary.opacity(0.6))
			Text(.localized("Offline"))
				.foregroundStyle(.secondary)
		}
		.font(.caption2.weight(.semibold))
		.padding(.horizontal, 10)
		.padding(.vertical, 5)
		.modifier(_PillSurface())
		.animation(.smooth(duration: 0.25), value: _status.hasWiFi)
		.animation(.smooth(duration: 0.25), value: _status.hasCellular)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text(.localized("No internet connection")))
	}
}

private struct _PillSurface: ViewModifier {
	func body(content: Content) -> some View {
		if #available(iOS 26, *) {
			content.glassEffect(.regular, in: Capsule())
		} else {
			content
				.background(.ultraThinMaterial, in: Capsule())
				.overlay(Capsule().stroke(Color.primary.opacity(0.08)))
		}
	}
}

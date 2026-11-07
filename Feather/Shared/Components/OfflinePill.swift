import Network
import SwiftUI

@MainActor
final class NetworkStatus: ObservableObject {
	static let shared = NetworkStatus()

	@Published private(set) var isOffline = false

	private let _monitor = NWPathMonitor()
	private var _pending: Task<Void, Never>?

	private init() {
		_monitor.pathUpdateHandler = { [weak self] path in
			let offline = path.status != .satisfied
			Task { @MainActor in self?._apply(offline: offline) }
		}
		_monitor.start(queue: DispatchQueue(label: "Feather.NetworkStatus"))
	}

	private func _apply(offline: Bool) {
		_pending?.cancel()
		guard offline != isOffline else { return }
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
		HStack(spacing: 8) {
			Image(systemName: "wifi.slash")
			Text(.localized("Offline"))
		}
		.font(.callout.weight(.semibold))
		.foregroundStyle(Color.red)
		.padding(.horizontal, 15)
		.padding(.vertical, 8)
		.modifier(_GlassCapsule())
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text(.localized("No internet connection")))
	}
}

private struct _GlassCapsule: ViewModifier {
	func body(content: Content) -> some View {
		if #available(iOS 26, *) {
			content.glassEffect(.regular, in: Capsule())
		} else {
			content
				.background(.regularMaterial, in: Capsule())
				.overlay(Capsule().stroke(Color.primary.opacity(0.08)))
				.shadow(color: .black.opacity(0.08), radius: 8, y: 3)
		}
	}
}

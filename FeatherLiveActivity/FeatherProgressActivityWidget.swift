import ActivityKit
import SwiftUI
import WidgetKit

struct FeatherProgressActivityWidget: Widget {
	var body: some WidgetConfiguration {
		ActivityConfiguration(for: FeatherProgressAttributes.self) { context in
			LockScreenProgressView(state: context.state)
		} dynamicIsland: { context in
			let state = context.state
			let tint = Color(activityHex: state.tint)
			return DynamicIsland {
				DynamicIslandExpandedRegion(.leading) {
					ProgressSymbol(state: state, tint: tint)
						.font(.title2)
						.padding(.leading, 6)
				}
				DynamicIslandExpandedRegion(.trailing) {
					Text(state.percentText)
						.font(.title3.weight(.semibold).monospacedDigit())
						.foregroundStyle(tint)
						.contentTransition(.numericText())
						.padding(.trailing, 6)
				}
				DynamicIslandExpandedRegion(.center) {
					Text(state.title)
						.font(.headline)
						.lineLimit(1)
				}
				DynamicIslandExpandedRegion(.bottom) {
					VStack(alignment: .leading, spacing: 8) {
						HStack {
							Text(state.detail)
								.font(.subheadline)
								.foregroundStyle(.secondary)
								.lineLimit(1)
							Spacer(minLength: 8)
							if state.others > 0 {
								Text("+\(state.others)")
									.font(.caption.weight(.semibold).monospacedDigit())
									.foregroundStyle(.secondary)
							}
						}
						ProgressBar(fraction: state.fraction, tint: tint)
					}
					.padding(.horizontal, 6)
					.padding(.top, 2)
				}
			} compactLeading: {
				ProgressSymbol(state: state, tint: tint)
					.padding(.leading, 2)
			} compactTrailing: {
				ProgressRing(fraction: state.fraction, tint: tint, finished: state.finished)
					.frame(width: 18, height: 18)
					.padding(.trailing, 2)
			} minimal: {
				ProgressRing(fraction: state.fraction, tint: tint, finished: state.finished)
					.frame(width: 18, height: 18)
			}
			.keylineTint(tint)
		}
	}
}

private struct LockScreenProgressView: View {
	let state: FeatherProgressAttributes.ContentState

	var body: some View {
		let tint = Color(activityHex: state.tint)
		VStack(alignment: .leading, spacing: 12) {
			HStack(spacing: 12) {
				ZStack {
					Circle().fill(tint.opacity(0.18))
					ProgressSymbol(state: state, tint: tint)
						.font(.title3)
				}
				.frame(width: 44, height: 44)
				VStack(alignment: .leading, spacing: 2) {
					Text(state.title)
						.font(.headline)
						.lineLimit(1)
					Text(state.others > 0 ? "\(state.detail) · +\(state.others)" : state.detail)
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}
				Spacer(minLength: 8)
				Text(state.percentText)
					.font(.title3.weight(.semibold).monospacedDigit())
					.foregroundStyle(tint)
					.contentTransition(.numericText())
			}
			ProgressBar(fraction: state.fraction, tint: tint)
		}
		.padding(16)
		.activitySystemActionForegroundColor(tint)
	}
}

private struct ProgressSymbol: View {
	let state: FeatherProgressAttributes.ContentState
	let tint: Color

	var body: some View {
		Image(systemName: state.symbol)
			.symbolRenderingMode(.hierarchical)
			.foregroundStyle(state.symbol.hasPrefix("xmark") ? Color.red : tint)
	}
}

private struct ProgressBar: View {
	let fraction: Double
	let tint: Color

	var body: some View {
		GeometryReader { proxy in
			ZStack(alignment: .leading) {
				Capsule().fill(tint.opacity(0.2))
				Capsule().fill(tint)
					.frame(width: max(6, proxy.size.width * min(1, max(0, fraction))))
			}
		}
		.frame(height: 6)
	}
}

private struct ProgressRing: View {
	let fraction: Double
	let tint: Color
	let finished: Bool

	var body: some View {
		ZStack {
			Circle().stroke(tint.opacity(0.25), lineWidth: 3)
			Circle()
				.trim(from: 0, to: finished ? 1 : min(1, max(0.02, fraction)))
				.stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
				.rotationEffect(.degrees(-90))
		}
	}
}

private extension FeatherProgressAttributes.ContentState {
	var percentText: String { "\(Int((min(1, max(0, fraction)) * 100).rounded()))%" }
}

private extension Color {
	init(activityHex hex: String) {
		let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
		var value: UInt64 = 0
		Scanner(string: cleaned).scanHexInt64(&value)
		let r, g, b: Double
		if cleaned.count == 6 {
			r = Double((value >> 16) & 0xFF) / 255
			g = Double((value >> 8) & 0xFF) / 255
			b = Double(value & 0xFF) / 255
		} else {
			r = 0.518; g = 0.557; b = 0.976
		}
		self.init(red: r, green: g, blue: b)
	}
}

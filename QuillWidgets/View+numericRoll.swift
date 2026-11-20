import SwiftUI

extension View {
	/// The rolling digit animation Apple uses for changing numbers: the old digits
	/// slide up and out while the new ones come in from below (reversed when the
	/// number goes down on iOS 17+). Pair with `.animation(_:value:)` or `withAnimation`.
	@ViewBuilder
	func numericRoll(_ value: Double) -> some View {
		if #available(iOS 17, *) {
			contentTransition(.numericText(value: value))
		} else {
			contentTransition(.numericText())
		}
	}

	func numericRoll<V: BinaryInteger>(_ value: V) -> some View {
		numericRoll(Double(value))
	}

	/// `numericRoll` plus the animation that drives it whenever `value` changes.
	func animatedNumber<V: BinaryInteger>(_ value: V) -> some View {
		numericRoll(value).animation(.snappy, value: value)
	}
}

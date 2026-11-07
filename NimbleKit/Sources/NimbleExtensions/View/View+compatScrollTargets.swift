import SwiftUI

extension View {
	@ViewBuilder
	public func compatScrollTargetLayout() -> some View {
		if #available(iOS 17.0, *) {
			self.scrollTargetLayout()
		} else {
			self
		}
	}

	@ViewBuilder
	public func compatScrollTargetBehavior() -> some View {
		if #available(iOS 17.0, *) {
			self.scrollTargetBehavior(.viewAligned)
		} else {
			self
		}
	}
}

import SwiftUI

public extension View {
	func nbReadableWidth(_ maxWidth: CGFloat = 720) -> some View {
		modifier(_ReadableWidth(maxWidth: maxWidth))
	}
}

private struct _ReadableWidth: ViewModifier {
	@Environment(\.horizontalSizeClass) private var _sizeClass
	let maxWidth: CGFloat

	func body(content: Content) -> some View {
		if #available(iOS 17, *), _sizeClass == .regular {
			GeometryReader { proxy in
				content.contentMargins(.horizontal, max(0, (proxy.size.width - maxWidth) / 2), for: .scrollContent)
			}
		} else {
			content
		}
	}
}

//
//  NBReadableWidth.swift
//  NimbleKit
//

import SwiftUI

public extension View {
	/// On a wide iPad screen, keeps a list or form's rows to a comfortable
	/// reading width while its background still fills the screen. Does nothing
	/// on iPhone or in narrow windows and sheets.
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

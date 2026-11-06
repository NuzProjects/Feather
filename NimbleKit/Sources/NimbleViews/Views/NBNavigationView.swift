//
//  NavigationViewWrapper.swift
//  Stars
//
//  Created by samara on 7.04.2025.
//

import SwiftUI

public struct NBNavigationView<Content>: View where Content: View {
	private var _title: String
	private var _mode: NavigationBarItem.TitleDisplayMode
	private var _content: Content
	
	public init(
		_ title: String,
		displayMode: NavigationBarItem.TitleDisplayMode = .automatic,
		@ViewBuilder content: () -> Content
	) {
		self._title = title
		self._mode = displayMode
		self._content = content()
	}
	
	public var body: some View {
		NavigationStack {
			_content
				.navigationTitle(_title)
				.navigationBarTitleDisplayMode(_mode)
				.nbSoftTopEdge()
		}
	}
}

public extension View {
	/// Blurs content as it scrolls under the navigation bar, like the Settings app (iOS 26+).
	func nbSoftTopEdge() -> some View {
		modifier(_SoftTopEdge())
	}
}

private struct _SoftTopEdge: ViewModifier {
	func body(content: Content) -> some View {
		if #available(iOS 26.0, *) {
			content.scrollEdgeEffectStyle(.soft, for: .top)
		} else {
			content
		}
	}
}

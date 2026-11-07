//
//  FRIconCellView.swift
//  NimbleKit
//
//  Created by samara on 3.05.2025.
//

import SwiftUI
import NukeUI
import NimbleViews

// MARK: - View
struct FRIconCellView: View {
	var title: String
	var subtitle: String
	var iconUrl: URL?
	var size: CGFloat = 56
	var isCircle: Bool = false
	var usesSkeletonPlaceholder: Bool = false
	
	// MARK: Body
	var body: some View {
		HStack(spacing: 18) {
			if let iconURL = iconUrl {
				LazyImage(url: iconURL) { state in
					if let image = state.image {
						image.appIconStyle(size: size, isCircle: isCircle)
					} else {
						standardIcon
					}
				}
			} else {
				standardIcon
			}
			
			NBTitleWithSubtitleView(
				title: title,
				subtitle: subtitle,
				linelimit: 0
			)
		}
	}
	
	@ViewBuilder
	var standardIcon: some View {
		if usesSkeletonPlaceholder {
			SkeletonCircle(size: size)
		} else {
			Image("App_Unknown")
				.appIconStyle(size: size, isCircle: isCircle)
		}
	}
}

private struct SkeletonCircle: View {
	let size: CGFloat
	@State private var _dim = false
	@Environment(\.accessibilityReduceMotion) private var _reduceMotion

	var body: some View {
		Circle()
			.fill(Color(uiColor: .secondarySystemFill))
			.frame(width: size, height: size)
			.opacity(_dim ? 0.45 : 1)
			.onAppear {
				guard !_reduceMotion else { return }
				withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { _dim = true }
			}
			.accessibilityHidden(true)
	}
}

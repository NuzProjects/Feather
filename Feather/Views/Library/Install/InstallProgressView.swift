//
//  InstallProgressView.swift
//  Feather
//
//  Created by samara on 23.04.2025.
//

import SwiftUI
import IDeviceSwift

struct InstallProgressView: View {
	@State private var _isPulsing = false
	
	var app: AppInfoPresentable
	@ObservedObject var viewModel: InstallerStatusViewModel
	
	var body: some View {
		VStack(spacing: 12) {
			_appIcon()
				.scaleEffect(_isPulsing ? 1.0 : 0.95)
				.animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: _isPulsing)
				.onAppear {
					_isPulsing = true
				}
		}
	}
	
	@ViewBuilder
	private func _appIcon() -> some View {
		ZStack {
			FRAppIconView(app: app, size: 80, lineWidth: 0)
				.opacity(0.2)
				.frame(width: 80, height: 80)
				.foregroundStyle(Color.black)
			
			FRAppIconView(app: app, size: 80, lineWidth: 0)
				.frame(width: 80, height: 80)
				.mask(
					ZStack {
						_iconShape.strokeBorder(Color.white, lineWidth: 6)
						PieShape(progress: viewModel.isCompleted ? 1 : viewModel.overallProgress)
							.clipShape(_iconShape)
							.animation(.smooth, value: viewModel.isCompleted)
					}
				)
				.animation(.smooth, value: viewModel.overallProgress)
		}
	}
	
	/// The same rounded-square shape iOS uses for app icons.
	private var _iconShape: RoundedRectangle {
		let ratio = ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)) ? 0.2677 : 0.2237
		return RoundedRectangle(cornerRadius: 80 * ratio, style: .continuous)
	}

	struct PieShape: Shape {
		var progress: Double
		
		func path(in rect: CGRect) -> Path {
			var path = Path()
			let center = CGPoint(x: rect.midX, y: rect.midY)
			// Reach the corners so the pie fills the whole icon shape.
			let radius = hypot(rect.width, rect.height) / 2
			let startAngle = Angle(degrees: -90)
			let endAngle = Angle(degrees: -90 + progress * 360)
			
			path.move(to: center)
			path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
			path.closeSubpath()
			
			return path
		}
		
		var animatableData: Double {
			get { progress }
			set { progress = newValue }
		}
	}
}

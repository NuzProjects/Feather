//
//  SourcesCellView.swift
//  Feather
//
//  Created by samara on 1.05.2025.
//

import SwiftUI
import NimbleViews
import NukeUI

// MARK: - View
struct SourcesCellView: View {
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@ObservedObject private var viewModel = SourcesViewModel.shared

	var source: AltSource

	private static let relativeFormatter = RelativeDateTimeFormatter()

	private var lastUpdated: Date? {
		viewModel.sources[source]?.apps.compactMap { $0.currentDate?.date }.max()
	}

	private var subtitle: String {
		let url = source.sourceURL?.absoluteString ?? ""
		guard let lastUpdated else { return url }
		let relative = Self.relativeFormatter.localizedString(for: lastUpdated, relativeTo: Date())
		return "Updated \(relative)\n\(url)"
	}

	var body: some View {
		let isRegular = horizontalSizeClass != .compact

		FRIconCellView(
			title: source.name ?? .localized("Unknown"),
			subtitle: subtitle,
			iconUrl: source.iconURL
		)
		.padding(isRegular ? 12 : 0)
		.background(
			isRegular
				? RoundedRectangle(cornerRadius: 18, style: .continuous)
				.fill(Color(.quaternarySystemFill))
				: nil
		)
		.swipeActions {
			_actions(for: source)
			_contextActions(for: source)
		}
		.contextMenu {
			_contextActions(for: source)
			Divider()
			_actions(for: source)
		}
	}
}

// MARK: - Extension: View
extension SourcesCellView {
	@ViewBuilder
	private func _actions(for source: AltSource) -> some View {
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteSource(for: source)
		}
	}
	
	@ViewBuilder
	private func _contextActions(for source: AltSource) -> some View {
		Button(.localized("Copy"), systemImage: "doc.on.clipboard") {
			UIPasteboard.general.string = source.sourceURL?.absoluteString
		}
	}
}

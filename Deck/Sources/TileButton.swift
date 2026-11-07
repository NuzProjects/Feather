import SwiftUI

struct TileButton: View {
	let tile: Tile
	let isEditing: Bool
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			VStack(spacing: 10) {
				Image(systemName: tile.symbol)
					.font(.system(size: 32, weight: .semibold))
				Text(tile.title)
					.font(.subheadline.weight(.semibold))
					.lineLimit(1)
			}
			.foregroundStyle(.white)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.contentShape(.rect(cornerRadius: 28))
		}
		.buttonStyle(.plain)
		.glassEffect(.regular.tint(tile.color.color.opacity(0.5)).interactive(), in: .rect(cornerRadius: 28))
		.overlay(alignment: .topTrailing) {
			if isEditing {
				Image(systemName: "pencil.circle.fill")
					.font(.title2)
					.symbolRenderingMode(.palette)
					.foregroundStyle(.white, .black.opacity(0.4))
					.padding(10)
					.transition(.scale.combined(with: .opacity))
			}
		}
	}
}

struct AddTileButton: View {
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			Image(systemName: "plus")
				.font(.system(size: 28, weight: .semibold))
				.foregroundStyle(.white.opacity(0.8))
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.contentShape(.rect(cornerRadius: 28))
		}
		.buttonStyle(.plain)
		.glassEffect(.clear.interactive(), in: .rect(cornerRadius: 28))
	}
}

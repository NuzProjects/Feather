import SwiftUI

struct TileEditor: View {
	@EnvironmentObject private var store: DeckStore
	@Environment(\.dismiss) private var dismiss

	let target: TileEditorTarget
	@State private var tile: Tile

	private static let symbols = [
		"globe", "music.note", "bubble.left.and.bubble.right.fill", "terminal.fill", "folder.fill",
		"envelope.fill", "calendar", "note.text", "gamecontroller.fill", "video.fill",
		"photo.fill", "camera.fill", "mic.fill", "headphones", "speaker.wave.2.fill",
		"play.fill", "pause.fill", "forward.fill", "backward.fill", "power",
		"lock.fill", "moon.fill", "sun.max.fill", "bolt.fill", "star.fill",
		"heart.fill", "cart.fill", "doc.fill", "paintbrush.fill", "hammer.fill",
		"chevron.left.forwardslash.chevron.right", "display", "keyboard", "printer.fill", "gearshape.fill"
	]

	init(target: TileEditorTarget) {
		self.target = target
		_tile = State(initialValue: target.tile ?? Tile(title: "New App", symbol: "app.fill", color: .blue))
	}

	var body: some View {
		NavigationStack {
			Form {
				Section {
					HStack {
						Spacer()
						TileButton(tile: tile, isEditing: false) {}
							.frame(width: 150, height: 120)
							.allowsHitTesting(false)
						Spacer()
					}
					.listRowBackground(Color.clear)
				}

				Section("Name") {
					TextField("Name", text: $tile.title)
				}

				Section("Icon") {
					LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 14) {
						ForEach(Self.symbols, id: \.self) { symbol in
							Image(systemName: symbol)
								.font(.title3)
								.frame(width: 44, height: 44)
								.background(tile.symbol == symbol ? tile.color.color.opacity(0.35) : .clear, in: .circle)
								.onTapGesture { tile.symbol = symbol }
						}
					}
					.padding(.vertical, 6)
				}

				Section("Color") {
					ScrollView(.horizontal) {
						HStack(spacing: 12) {
							ForEach(TileColor.allCases) { color in
								Circle()
									.fill(color.color)
									.frame(width: 34, height: 34)
									.overlay {
										if tile.color == color {
											Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
										}
									}
									.onTapGesture { tile.color = color }
							}
						}
						.padding(.vertical, 6)
					}
					.scrollIndicators(.hidden)
				}

				Section {
					TextField("App or command", text: $tile.command)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
				} header: {
					Text("On Your Computer")
				} footer: {
					Text("What this button opens once Deck is connected to your computer.")
				}

				if target.tile != nil {
					Section {
						Button("Delete", role: .destructive) {
							store.delete(tile, onPage: target.page)
							dismiss()
						}
					}
				}
			}
			.navigationTitle(target.tile == nil ? "New App" : "Edit App")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						store.save(tile, onPage: target.page)
						dismiss()
					}
					.disabled(tile.title.trimmingCharacters(in: .whitespaces).isEmpty)
				}
			}
		}
		.presentationDetents([.large])
	}
}

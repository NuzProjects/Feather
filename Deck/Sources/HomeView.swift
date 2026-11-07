import SwiftUI

struct HomeView: View {
	@EnvironmentObject private var store: DeckStore
	@State private var currentPage: Int? = 0
	@State private var isEditing = false
	@State private var editing: TileEditorTarget?

	var body: some View {
		NavigationStack {
			ZStack(alignment: .leading) {
				DeckBackground()

				ScrollView(.vertical) {
					LazyVStack(spacing: 0) {
						ForEach(Array(store.pages.enumerated()), id: \.element.id) { index, page in
							PageGrid(page: page, isEditing: isEditing) { tile in
								if isEditing {
									editing = TileEditorTarget(page: index, tile: tile)
								} else {
									store.trigger(tile)
								}
							} onAdd: {
								editing = TileEditorTarget(page: index, tile: nil)
							}
							.containerRelativeFrame([.horizontal, .vertical])
							.id(index)
						}
					}
					.scrollTargetLayout()
				}
				.scrollTargetBehavior(.paging)
				.scrollPosition(id: $currentPage)
				.scrollIndicators(.hidden)

				if store.pages.count > 1 {
					PageIndicator(count: store.pages.count, selection: $currentPage)
						.padding(.leading, 10)
				}
			}
			.overlay(alignment: .bottom) {
				if let tile = store.lastTriggered {
					TriggerBanner(tile: tile)
						.padding(.bottom, 12)
						.transition(.move(edge: .bottom).combined(with: .opacity))
				}
			}
			.animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.lastTriggered)
			.navigationTitle("Deck")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				if isEditing && store.canAddPage {
					ToolbarItem(placement: .topBarLeading) {
						Button("Add Page", systemImage: "plus.rectangle.on.rectangle") {
							store.addPage()
							withAnimation { currentPage = store.pages.count - 1 }
						}
					}
				}
				ToolbarItem(placement: .topBarTrailing) {
					Button(isEditing ? "Done" : "Edit") {
						withAnimation(.smooth) { isEditing.toggle() }
					}
				}
			}
			.sheet(item: $editing) { target in
				TileEditor(target: target)
			}
		}
	}
}

struct TileEditorTarget: Identifiable {
	let page: Int
	let tile: Tile?
	var id: String { "\(page)-\(tile?.id.uuidString ?? "new")" }
}

private struct PageGrid: View {
	let page: Page
	let isEditing: Bool
	let onTap: (Tile) -> Void
	let onAdd: () -> Void

	private let spacing: CGFloat = 14

	var body: some View {
		GeometryReader { proxy in
			let height = (proxy.size.height - spacing * 3) / 4
			let columns = [GridItem(.flexible(), spacing: spacing), GridItem(.flexible(), spacing: spacing)]
			LazyVGrid(columns: columns, spacing: spacing) {
				ForEach(page.tiles) { tile in
					TileButton(tile: tile, isEditing: isEditing) { onTap(tile) }
						.frame(height: height)
				}
				if isEditing && page.tiles.count < DeckStore.tilesPerPage {
					AddTileButton(action: onAdd)
						.frame(height: height)
				}
			}
		}
		.padding(.leading, 44)
		.padding(.trailing, 20)
		.padding(.vertical, 16)
	}
}

private struct PageIndicator: View {
	let count: Int
	@Binding var selection: Int?

	var body: some View {
		VStack(spacing: 2) {
			ForEach(0..<count, id: \.self) { index in
				Circle()
					.fill(.white.opacity(index == (selection ?? 0) ? 1 : 0.35))
					.frame(width: 8, height: 8)
					.padding(5)
					.contentShape(Rectangle())
					.onTapGesture {
						withAnimation(.smooth) { selection = index }
					}
			}
		}
		.padding(.vertical, 9)
		.padding(.horizontal, 4)
		.glassEffect(.regular, in: .capsule)
		.animation(.smooth, value: selection)
	}
}

private struct TriggerBanner: View {
	let tile: Tile

	var body: some View {
		Label("Opening \(tile.title)", systemImage: tile.symbol)
			.font(.subheadline.weight(.semibold))
			.padding(.horizontal, 18)
			.padding(.vertical, 12)
			.glassEffect(.regular, in: .capsule)
	}
}

struct DeckBackground: View {
	var body: some View {
		MeshGradient(
			width: 3,
			height: 3,
			points: [
				[0, 0], [0.5, 0], [1, 0],
				[0, 0.5], [0.55, 0.45], [1, 0.5],
				[0, 1], [0.5, 1], [1, 1]
			],
			colors: [
				.indigo, .purple, .blue,
				.black, .indigo.opacity(0.8), .purple.opacity(0.7),
				.black, .blue.opacity(0.6), .black
			]
		)
		.ignoresSafeArea()
	}
}

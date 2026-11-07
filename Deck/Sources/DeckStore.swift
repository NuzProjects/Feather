import SwiftUI

struct Tile: Identifiable, Codable, Hashable {
	var id = UUID()
	var title: String
	var symbol: String
	var color: TileColor
	var command = ""
}

enum TileColor: String, Codable, CaseIterable, Identifiable {
	case blue, indigo, purple, pink, red, orange, yellow, green, teal, gray

	var id: String { rawValue }

	var color: Color {
		switch self {
		case .blue: .blue
		case .indigo: .indigo
		case .purple: .purple
		case .pink: .pink
		case .red: .red
		case .orange: .orange
		case .yellow: .yellow
		case .green: .green
		case .teal: .teal
		case .gray: .gray
		}
	}
}

struct Page: Identifiable, Codable, Hashable {
	var id = UUID()
	var tiles: [Tile] = []
}

@MainActor
final class DeckStore: ObservableObject {
	static let maxPages = 3
	static let tilesPerPage = 8

	@Published var pages: [Page] {
		didSet { save() }
	}
	@Published private(set) var lastTriggered: Tile?

	private let key = "Deck.pages"

	init() {
		if let data = UserDefaults.standard.data(forKey: key),
		   let saved = try? JSONDecoder().decode([Page].self, from: data),
		   !saved.isEmpty {
			pages = saved
		} else {
			pages = [Page(tiles: Self.starterTiles)]
		}
	}

	static let starterTiles: [Tile] = [
		Tile(title: "Browser", symbol: "globe", color: .blue),
		Tile(title: "Music", symbol: "music.note", color: .pink),
		Tile(title: "Chat", symbol: "bubble.left.and.bubble.right.fill", color: .indigo),
		Tile(title: "Terminal", symbol: "terminal.fill", color: .gray),
		Tile(title: "Files", symbol: "folder.fill", color: .teal),
		Tile(title: "Mail", symbol: "envelope.fill", color: .orange),
		Tile(title: "Calendar", symbol: "calendar", color: .red),
		Tile(title: "Notes", symbol: "note.text", color: .yellow)
	]

	var canAddPage: Bool { pages.count < Self.maxPages }

	func addPage() {
		guard canAddPage else { return }
		pages.append(Page())
	}

	func removePage(at index: Int) {
		guard pages.count > 1, pages.indices.contains(index) else { return }
		pages.remove(at: index)
	}

	func setPageCount(_ count: Int) {
		let target = min(max(count, 1), Self.maxPages)
		while pages.count < target { pages.append(Page()) }
		while pages.count > target { pages.removeLast() }
	}

	func save(_ tile: Tile, onPage page: Int) {
		guard pages.indices.contains(page) else { return }
		if let index = pages[page].tiles.firstIndex(where: { $0.id == tile.id }) {
			pages[page].tiles[index] = tile
		} else if pages[page].tiles.count < Self.tilesPerPage {
			pages[page].tiles.append(tile)
		}
	}

	func delete(_ tile: Tile, onPage page: Int) {
		guard pages.indices.contains(page) else { return }
		pages[page].tiles.removeAll { $0.id == tile.id }
	}

	func reset() {
		pages = [Page(tiles: Self.starterTiles)]
	}

	/// Sending to a computer comes later; for now this confirms the tap.
	func trigger(_ tile: Tile) {
		if UserDefaults.standard.object(forKey: "Deck.haptics") as? Bool ?? true {
			UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		}
		lastTriggered = tile
		Task {
			try? await Task.sleep(for: .seconds(1.6))
			if lastTriggered?.id == tile.id { lastTriggered = nil }
		}
	}

	private func save() {
		if let data = try? JSONEncoder().encode(pages) {
			UserDefaults.standard.set(data, forKey: key)
		}
	}
}

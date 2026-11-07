import SwiftUI

@main
struct DeckApp: App {
	@StateObject private var store = DeckStore()

	var body: some Scene {
		WindowGroup {
			TabView {
				Tab("Apps", systemImage: "square.grid.2x2.fill") {
					HomeView()
				}
				Tab("Settings", systemImage: "gearshape.fill") {
					SettingsView()
				}
			}
			.environmentObject(store)
			.preferredColorScheme(.dark)
		}
	}
}

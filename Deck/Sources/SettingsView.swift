import SwiftUI

struct SettingsView: View {
	@EnvironmentObject private var store: DeckStore
	@AppStorage("Deck.computerHost") private var host = ""
	@AppStorage("Deck.computerPort") private var port = "5050"
	@AppStorage("Deck.haptics") private var haptics = true
	@State private var confirmingReset = false

	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField("Computer address", text: $host)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
						.keyboardType(.URL)
					TextField("Port", text: $port)
						.keyboardType(.numberPad)
				} header: {
					Text("Computer")
				} footer: {
					Text("Connecting to your computer is coming soon. Buttons will open apps on it once it's set up.")
				}

				Section("Layout") {
					Stepper(value: Binding(get: { store.pages.count }, set: { store.setPageCount($0) }), in: 1...DeckStore.maxPages) {
						LabeledContent("Pages", value: "\(store.pages.count)")
					}
					Toggle("Haptics", isOn: $haptics)
				}

				Section {
					Button("Reset Layout", role: .destructive) { confirmingReset = true }
				} footer: {
					Text("Brings back the starter apps on one page.")
				}

				Section {
					LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
				}
			}
			.scrollContentBackground(.hidden)
			.background(DeckBackground())
			.navigationTitle("Settings")
			.confirmationDialog("Reset your layout?", isPresented: $confirmingReset, titleVisibility: .visible) {
				Button("Reset Layout", role: .destructive) { store.reset() }
			}
		}
	}
}

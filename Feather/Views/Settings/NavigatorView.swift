import SwiftUI
import NimbleViews
final class NavigatorPreferences: ObservableObject {
    static let shared = NavigatorPreferences()
    @Published var showLabels: Bool { didSet { UserDefaults.standard.set(showLabels, forKey: "Navigator.labels") } }
    @Published private(set) var tabs: [TabEnum]
    private init() {
        showLabels = UserDefaults.standard.object(forKey: "Navigator.labels") as? Bool ?? true
        tabs = NavigatorRules.sanitize(UserDefaults.standard.stringArray(forKey: "Navigator.tabs") ?? ["sources", "library", "settings"]).compactMap(TabEnum.init(rawValue:))
    }
    func set(_ items: [TabEnum]) {
        tabs = NavigatorRules.sanitize(items.map(\.rawValue)).compactMap(TabEnum.init(rawValue:))
        UserDefaults.standard.set(tabs.map(\.rawValue), forKey: "Navigator.tabs")
    }
}
struct NavigatorView: View {
    @State private var editMode: EditMode = .inactive
    @ObservedObject private var preferences = NavigatorPreferences.shared
    var body: some View {
        NBList("Navigator") {
            Section {
                Toggle(isOn: $preferences.showLabels) { Label("Show Labels", systemImage: "textformat") }
            }
            Section {
                ForEach(preferences.tabs, id: \.self) { tab in
                    row(tab, visible: true)
                }
                .onMove { indices, offset in
                    withAnimation(.smooth(duration: 0.25)) {
                        var tabs = preferences.tabs
                        tabs.move(fromOffsets: indices, toOffset: offset)
                        preferences.set(tabs)
                    }
                }
            } header: { Text("Navigation") } footer: { Text("Use Reorder to arrange tabs.") }
            let hidden = TabEnum.allCases.filter { !preferences.tabs.contains($0) }
            if !hidden.isEmpty {
                Section("Hidden") { ForEach(hidden, id: \.self) { row($0, visible: false) } }
            }
        }
        .symbolVariant(.fill)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(editMode.isEditing ? "Done" : "Reorder") { withAnimation(.smooth(duration: 0.25)) { editMode = editMode.isEditing ? .inactive : .active } } } }
        .environment(\.editMode, $editMode)
    }
    private func row(_ tab: TabEnum, visible: Bool) -> some View {
        HStack {
            Label(tab.title, systemImage: tab.icon)
            Spacer()
            if tab != .settings {
                Button(visible ? "Hide" : "Show") {
                    withAnimation(.smooth(duration: 0.25)) { preferences.set(visible ? preferences.tabs.filter { $0 != tab } : preferences.tabs + [tab]) }
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

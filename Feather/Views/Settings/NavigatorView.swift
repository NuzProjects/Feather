import SwiftUI
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
    @ObservedObject private var preferences = NavigatorPreferences.shared
    var body: some View {
        List {
            Section { Toggle("Show Labels", isOn: $preferences.showLabels) }
            Section {
                ForEach(preferences.tabs, id: \.self) { tab in
                    HStack {
                        Label(tab.title, systemImage: tab.icon)
                        Spacer()
                        if tab == .settings { Image(systemName: "lock.fill").foregroundStyle(.secondary).accessibilityLabel("Always visible") }
                    }.deleteDisabled(tab == .settings)
                }
                .onMove { indices, offset in
                    var tabs = preferences.tabs; tabs.move(fromOffsets: indices, toOffset: offset); preferences.set(tabs)
                }
                .onDelete { indices in
                    preferences.set(preferences.tabs.enumerated().filter { !indices.contains($0.offset) || $0.element == .settings }.map(\.element))
                }
            } header: { Text("Navigation Items") } footer: { Text("Drag to reorder. Settings always stays available.") }
            let hidden = TabEnum.allCases.filter { !preferences.tabs.contains($0) }
            if !hidden.isEmpty {
                Section("Add Navigation Item") {
                    ForEach(hidden, id: \.self) { tab in
                        Button { preferences.set(preferences.tabs + [tab]) } label: { Label(tab.title, systemImage: "plus.circle") }
                    }
                }
            }
        }.environment(\.editMode, .constant(.active)).navigationTitle("Navigator")
    }
}

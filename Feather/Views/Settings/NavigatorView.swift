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
        NBList("Navigator", type: .list) {
            NBSection("Appearance") { Toggle("Show Labels", isOn: $preferences.showLabels) }
            NBSection("Navigation") {
                ForEach(preferences.tabs, id: \.self) { tab in
                    row(tab, visible: true)
                }
                .onMove { indices, offset in
                    var tabs = preferences.tabs
                    tabs.move(fromOffsets: indices, toOffset: offset)
                    preferences.set(tabs)
                }
            } footer: { Text("Use Edit to reorder. Settings always stays available.") }
            let hidden = TabEnum.allCases.filter { !preferences.tabs.contains($0) }
            if !hidden.isEmpty {
                NBSection("Hidden") { ForEach(hidden, id: \.self) { row($0, visible: false) } }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { EditButton() } }
        .environment(\.editMode, $editMode)
    }
    private func row(_ tab: TabEnum, visible: Bool) -> some View {
        HStack(spacing: 18) {
            Image(systemName: tab.icon)
                .font(.system(size: 24, weight: .medium))
                .frame(width: 56, height: 56)
                .background(Color(uiColor: .quaternarySystemFill), in: RoundedRectangle(cornerRadius: 14))
            NBTitleWithSubtitleView(title: tab.title, subtitle: tab == .settings ? "Always available" : (visible ? "Shown in navigation" : "Hidden from navigation"), linelimit: 0)
            if tab != .settings {
                Button(visible ? "Hide" : "Show") {
                    preferences.set(visible ? preferences.tabs.filter { $0 != tab } : preferences.tabs + [tab])
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
        }
        .padding(.vertical, 4)
    }
}

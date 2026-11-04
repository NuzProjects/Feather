import SwiftUI

struct TabbarView: View {
    @ObservedObject private var navigator = NavigatorPreferences.shared
    @State private var selected: TabEnum = NavigatorPreferences.shared.tabs.first ?? .settings

    var body: some View {
        TabView(selection: $selected) {
            ForEach(navigator.tabs, id: \.self) { tab in
                TabEnum.view(for: tab)
                    .environment(\.managedObjectContext, Storage.shared.context)
                    .tabItem {
                        if navigator.showLabels { Label(tab.title, systemImage: tab.icon) }
                        else { Image(systemName: tab.icon).accessibilityLabel(tab.title) }
                    }
                    .tag(tab)
            }
        }
        .symbolVariant(.fill)
        .overlay(alignment: .bottom) {
            ActivityProgressPanel().padding(.bottom, 58)
        }
        .onChange(of: navigator.tabs) { tabs in
            if !tabs.contains(selected) { selected = tabs.contains(.settings) ? .settings : (tabs.first ?? .settings) }
        }
    }
}

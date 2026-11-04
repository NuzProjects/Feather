import SwiftUI
import UIKit

struct TabbarView: View {
    @ObservedObject private var navigator = NavigatorPreferences.shared
    @State private var selected: TabEnum = NavigatorPreferences.shared.tabs.first ?? .settings

    var body: some View {
        TabView(selection: $selected) {
            ForEach(navigator.tabs, id: \.self) { tab in
                TabEnum.view(for: tab)
                    .environment(\.managedObjectContext, Storage.shared.context)
                    .tabItem { Label(tab.title, systemImage: tab.icon) }
                    .tag(tab)
            }
        }
        .symbolVariant(.fill)
        .background(TabLabelApplier(tabs: navigator.tabs, showLabels: navigator.showLabels))
        .overlay(alignment: .bottom) {
            ActivityProgressPanel().padding(.bottom, 58)
        }
        .onChange(of: navigator.tabs) { tabs in
            if !tabs.contains(selected) { selected = tabs.contains(.settings) ? .settings : (tabs.first ?? .settings) }
        }
    }
}

/// SwiftUI's tab bar has no label toggle, so the underlying UITabBarItems are updated directly.
private struct TabLabelApplier: UIViewControllerRepresentable {
    let tabs: [TabEnum]
    let showLabels: Bool
    func makeUIViewController(context: Context) -> Applier { Applier() }
    func updateUIViewController(_ controller: Applier, context: Context) {
        controller.tabs = tabs
        controller.showLabels = showLabels
        controller.apply()
        DispatchQueue.main.async { controller.apply() }
    }
    final class Applier: UIViewController {
        var tabs: [TabEnum] = []
        var showLabels = true
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); apply() }
        func apply() {
            guard let window = view.window, let bar = window.firstTabBar, let items = bar.items, items.count == tabs.count else { return }
            for (item, tab) in zip(items, tabs) {
                item.title = showLabels ? tab.title : nil
                item.accessibilityLabel = tab.title
                item.imageInsets = showLabels ? .zero : UIEdgeInsets(top: 6, left: 0, bottom: -6, right: 0)
            }
        }
    }
}

private extension UIView {
    var firstTabBar: UITabBar? {
        if let bar = self as? UITabBar { return bar }
        for sub in subviews { if let bar = sub.firstTabBar { return bar } }
        return nil
    }
}

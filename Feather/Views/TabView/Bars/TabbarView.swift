import SwiftUI
import UIKit

struct TabbarView: View {
    @ObservedObject private var navigator = NavigatorPreferences.shared
    var body: some View { NativeNavigator(tabs: navigator.tabs, showLabels: navigator.showLabels).ignoresSafeArea() }
}

private struct NativeNavigator: UIViewControllerRepresentable {
    let tabs: [TabEnum]
    let showLabels: Bool
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> NativeTabController {
        let controller = NativeTabController()
        controller.delegate = context.coordinator
        let panel = UIHostingController(rootView: SigningProgressPanel())
        panel.sizingOptions = .intrinsicContentSize
        panel.view.backgroundColor = .clear
        panel.view.translatesAutoresizingMaskIntoConstraints = false
        controller.addChild(panel)
        controller.view.addSubview(panel.view)
        NSLayoutConstraint.activate([
            panel.view.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
            panel.view.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
            panel.view.bottomAnchor.constraint(equalTo: controller.tabBar.topAnchor, constant: -10)
        ])
        panel.didMove(toParent: controller)
        context.coordinator.panel = panel
        controller.progressPanel = panel.view
        return controller
    }
    func updateUIViewController(_ controller: NativeTabController, context: Context) {
        let selected = controller.selectedViewController
        let pages: [UIViewController] = tabs.map { tab in
            let page: UIHostingController<AnyView>
            if let existing = context.coordinator.pages[tab] { page = existing }
            else {
                page = UIHostingController(rootView: AnyView(TabEnum.view(for: tab).environment(\.managedObjectContext, Storage.shared.context)))
                context.coordinator.pages[tab] = page
            }
            page.tabBarItem.title = showLabels ? tab.title : ""
            page.tabBarItem.image = UIImage(systemName: tab.icon)
            page.tabBarItem.accessibilityLabel = tab.title
            return page
        }
        if controller.viewControllers != pages {
            controller.setViewControllers(pages, animated: false)
            if selected == nil { controller.selectedViewController = pages.first }
            else if let selected, pages.contains(selected) { controller.selectedViewController = selected }
            else if let settings = context.coordinator.pages[.settings] { controller.selectedViewController = settings }
        }
        controller.tabBar.setNeedsLayout()
    }
    final class Coordinator: NSObject, UITabBarControllerDelegate {
        var panel: UIHostingController<SigningProgressPanel>?
        var pages: [TabEnum: UIHostingController<AnyView>] = [:]
    }
}

private final class NativeTabController: UITabBarController {
    weak var progressPanel: UIView?
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let progressPanel { view.bringSubviewToFront(progressPanel) }
    }
}

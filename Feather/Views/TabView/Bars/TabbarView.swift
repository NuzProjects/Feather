import SwiftUI
import UIKit

struct TabbarView: View {
    @ObservedObject private var navigator = NavigatorPreferences.shared
    @State private var selected: TabEnum = NavigatorPreferences.shared.tabs.first ?? .settings
    @ObservedObject private var updater = FeatherUpdater.shared
    @State private var installingFromPrompt = false
    @State private var showWhatsNew = false
    @State private var showOnboarding = false

    var body: some View {
        TabView(selection: Binding(get: { selected }, set: { new in if new != selected { TabTransition.crossfade() }; selected = new })) {
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
            VStack(spacing: 0) {
                ActivityProgressPanel()
                OfflinePill()
            }
                .padding(.bottom, 58)
                .background(alignment: .bottom) {
                    if let update = updater.signedUpdate {
                        InstallPreviewView(
                            app: update.base,
                            inBackground: true,
                            onClose: { updater.signedUpdate = nil },
                            onProgress: { label, fraction in
                                updater.installLabel = label
                                updater.installFraction = fraction
                            }
                        )
                        .id(update.id)
                    }
                }
        }
        .onChange(of: navigator.tabs) { tabs in
            if !tabs.contains(selected) { selected = tabs.contains(.settings) ? .settings : (tabs.first ?? .settings) }
        }
        .task {
            if !UserDefaults.standard.bool(forKey: "Feather.serverMethodSemiLocal") {
                UserDefaults.standard.set(1, forKey: "Feather.serverMethod")
                UserDefaults.standard.set(true, forKey: "Feather.serverMethodSemiLocal")
            }
            SSLCertificateCheck.run()
            Storage.shared.checkAllRevocations()
            if Onboarding.shouldShow { showOnboarding = true; return }
            CertificateExpiry.refresh()
            if WhatsNew.shouldShow { showWhatsNew = true }
            else { await updater.checkOnLaunch() }
        }
        .fullScreenCover(isPresented: $showOnboarding, onDismiss: {
            Onboarding.markSeen()
            WhatsNew.markSeen()
            CertificateExpiry.refresh()
        }) {
            OnboardingView()
        }
        .sheet(isPresented: $showWhatsNew, onDismiss: { Task { await updater.checkOnLaunch() } }) {
            WhatsNewView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert(
            "Update Available",
            isPresented: Binding(get: { updater.promptRelease != nil }, set: { if !$0 { updater.promptRelease = nil } }),
            presenting: updater.promptRelease
        ) { release in
            Button("Update") {
                if navigator.tabs.contains(.settings) {
                    if selected != .settings { TabTransition.crossfade() }
                    selected = .settings
                    updater.openUpdatesPage = true
                } else {
                    installingFromPrompt = true
                }
                updater.install()
            }
            Button("Later", role: .cancel) { updater.skip(release) }
        } message: { release in
            Text("Feather \(FeatherUpdater.displayName(release)) is ready to install.\n\n\(updater.plainReleaseNotes ?? "")")
        }
        .onChange(of: updater.phase) { phase in
            guard installingFromPrompt else { return }
            switch phase {
            case .failed(let message):
                installingFromPrompt = false
                UIAlertController.showAlertWithOk(title: "Update Failed", message: message)
            case .ready, .idle:
                installingFromPrompt = false
            default:
                break
            }
        }
    }
}

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
        private var appliedLabels: Bool?
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); apply() }
        func apply() {
            guard let window = view.window, let bar = window.firstTabBar, let items = bar.items, items.count == tabs.count else { return }
            let showLabels = showLabels
            let update = {
                for (item, tab) in zip(items, self.tabs) {
                    item.title = showLabels ? tab.title : nil
                    item.accessibilityLabel = tab.title
                    item.imageInsets = showLabels ? .zero : UIEdgeInsets(top: 6, left: 0, bottom: -6, right: 0)
                }
                bar.setNeedsLayout()
                bar.layoutIfNeeded()
            }
            if let appliedLabels, appliedLabels != showLabels, !UIAccessibility.isReduceMotionEnabled {
                UIView.transition(with: bar, duration: 0.32, options: [.transitionCrossDissolve, .allowUserInteraction, .beginFromCurrentState], animations: update)
            } else {
                update()
            }
            appliedLabels = showLabels
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

enum TabTransition {
    @MainActor static func crossfade() {
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first(where: \.isKeyWindow),
              let bar = window.firstTabBar else { return }
        let height = bar.convert(bar.bounds, to: window).minY
        guard height > 0, let snapshot = window.resizableSnapshotView(from: CGRect(x: 0, y: 0, width: window.bounds.width, height: height), afterScreenUpdates: false, withCapInsets: .zero) else { return }
        snapshot.isUserInteractionEnabled = false
        window.addSubview(snapshot)
        UIView.animate(withDuration: 0.28, delay: 0.04, options: [.curveEaseInOut, .allowUserInteraction]) { snapshot.alpha = 0 } completion: { _ in snapshot.removeFromSuperview() }
    }
}

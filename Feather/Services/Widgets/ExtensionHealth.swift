import Foundation
import UIKit

@MainActor
enum ExtensionHealth {
	enum State: Equatable {
		case ready
		case needsReinstall
		case unsupported
	}

	private static let promptedKey = "Widgets.promptedState"

	private static var appProfileURL: URL { Bundle.main.bundleURL.appendingPathComponent("embedded.mobileprovision") }
	private static var widgetsURL: URL? { Bundle.main.builtInPlugInsURL?.appendingPathComponent("FeatherWidgets.appex") }

	private static var hasWidgetsExtension: Bool {
		guard let widgetsURL else { return false }
		return FileManager.default.fileExists(atPath: widgetsURL.path)
	}

	private static var widgetsHaveProfile: Bool {
		guard let widgetsURL else { return false }
		return FileManager.default.fileExists(atPath: widgetsURL.appendingPathComponent("embedded.mobileprovision").path)
	}

	private static var isProvisioned: Bool { FileManager.default.fileExists(atPath: appProfileURL.path) }

	static var extensionsCanRun: Bool {
		hasWidgetsExtension && (widgetsHaveProfile || !isProvisioned)
	}

	static var selectedCertificateCoversOneApp: Bool {
		guard
			let certificate = Storage.shared.getCertificate(for: UserDefaults.standard.integer(forKey: "feather.selectedCert")),
			let identifier = Storage.shared.getProvisionFileDecoded(for: certificate)?.Entitlements?["application-identifier"]?.value as? String
		else { return false }
		return !identifier.hasSuffix("*")
	}

	static var state: State {
		if extensionsCanRun { return .ready }
		if selectedCertificateCoversOneApp { return .unsupported }
		return isProvisioned ? .needsReinstall : .ready
	}

	static func check() {
		_logStatus()
		let current = state
		guard current != .ready else {
			UserDefaults.standard.removeObject(forKey: promptedKey)
			return
		}
		let key = "\(current)-\(FeatherUpdater.shared.currentVersion)"
		guard UserDefaults.standard.string(forKey: promptedKey) != key else { return }
		_present(current) { UserDefaults.standard.set(key, forKey: promptedKey) }
	}

	private static func _present(_ state: State, attempt: Int = 0, onShown: @escaping () -> Void) {
		guard state != .ready else { return }
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
			guard let top = UIApplication.topViewController(), !top.isBeingPresented, !top.isBeingDismissed, !(top is UIAlertController) else {
				if attempt < 20 { _present(state, attempt: attempt + 1, onShown: onShown) }
				return
			}
			switch state {
			case .needsReinstall:
				UIAlertController.showAlert(
					top,
					title: String.localized("Finish Setting Up Widgets"),
					message: String.localized("Feather needs to reinstall itself once so Home Screen widgets and Live Activities can run. Your apps, sources and settings are kept."),
					actions: [
						UIAlertAction(title: String.localized("Reinstall"), style: .default) { _ in FeatherUpdater.shared.install() },
						UIAlertAction(title: String.localized("Not Now"), style: .cancel)
					]
				)
			case .unsupported:
				UIAlertController.showAlert(
					top,
					title: String.localized("Widgets Unavailable"),
					message: String.localized("Your certificate only covers one app ID, so iOS won't install the extension that Home Screen widgets and Live Activities need. They work with a certificate that covers all app IDs."),
					actions: [UIAlertAction(title: String.localized("OK"), style: .cancel)]
				)
			case .ready:
				return
			}
			onShown()
		}
	}

	private static func _logStatus() {
		let profile: String
		switch _applicationIdentifier(at: appProfileURL) {
		case nil: profile = "none"
		case let id? where id.hasSuffix("*"): profile = "all app IDs"
		case .some: profile = "one app ID"
		}
		let selected = selectedCertificateCoversOneApp ? "one app ID" : "all app IDs"
		let widgets = !hasWidgetsExtension ? "missing" : (widgetsHaveProfile ? "installed with profile" : "installed without profile")
		let keychain = WidgetSnapshotStore.accessGroup == nil ? "unavailable" : "available"
		DevLog.shared.log(.info, "Installed profile covers \(profile). Selected certificate covers \(selected). Widget extension \(widgets). Shared keychain \(keychain).", category: "Widgets")
	}

	private static func _applicationIdentifier(at url: URL) -> String? {
		guard
			let data = try? Data(contentsOf: url),
			let start = data.range(of: Data("<?xml".utf8)),
			let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
			let plist = try? PropertyListSerialization.propertyList(from: data.subdata(in: start.lowerBound..<end.upperBound), format: nil) as? [String: Any],
			let entitlements = plist["Entitlements"] as? [String: Any]
		else { return nil }
		return entitlements["application-identifier"] as? String
	}
}

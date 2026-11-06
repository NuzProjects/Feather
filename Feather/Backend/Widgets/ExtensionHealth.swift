import Foundation
import UIKit

// Widgets and Live Activities only run when their extension carries its own
// provisioning profile. Copies signed before 1.3.1 Beta 6 left it out, so offer
// a one-time reinstall, which re-signs the extension with the fixed signer.
@MainActor
enum ExtensionHealth {
	private static let promptedKey = "Widgets.repairPromptedVersion"

	private static var appProfileURL: URL { Bundle.main.bundleURL.appendingPathComponent("embedded.mobileprovision") }
	private static var widgetsURL: URL? { Bundle.main.builtInPlugInsURL?.appendingPathComponent("FeatherWidgets.appex") }

	static var needsRepair: Bool {
		guard
			let widgetsURL,
			FileManager.default.fileExists(atPath: widgetsURL.path),
			FileManager.default.fileExists(atPath: appProfileURL.path)
		else { return false }
		return !FileManager.default.fileExists(atPath: widgetsURL.appendingPathComponent("embedded.mobileprovision").path)
	}

	static func check() {
		_logStatus()
		guard needsRepair else { return }
		let version = FeatherUpdater.shared.currentVersion
		guard UserDefaults.standard.string(forKey: promptedKey) != version else { return }
		UserDefaults.standard.set(version, forKey: promptedKey)
		let reinstall = UIAlertAction(title: String.localized("Reinstall"), style: .default) { _ in
			FeatherUpdater.shared.install()
		}
		let later = UIAlertAction(title: String.localized("Not Now"), style: .cancel)
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
			UIAlertController.showAlert(
				title: String.localized("Finish Setting Up Widgets"),
				message: String.localized("Feather needs to reinstall itself once so Home Screen widgets and Live Activities can run. Your apps, sources and settings are kept."),
				actions: [reinstall, later]
			)
		}
	}

	private static func _logStatus() {
		let profile: String
		switch _applicationIdentifier(at: appProfileURL) {
		case nil: profile = "none"
		case let id? where id.hasSuffix("*"): profile = "all app IDs"
		case let id?: profile = "one app ID (\(id.split(separator: ".", maxSplits: 1).last.map(String.init) ?? id))"
		}
		let widgetProfile = widgetsURL.map { FileManager.default.fileExists(atPath: $0.appendingPathComponent("embedded.mobileprovision").path) } ?? false
		let keychain = WidgetSnapshotStore.accessGroup == nil ? "unavailable" : "available"
		DevLog.shared.log(.info, "Certificate profile covers \(profile). Widget extension profile \(widgetProfile ? "present" : "missing"). Shared keychain \(keychain).", category: "Widgets")
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

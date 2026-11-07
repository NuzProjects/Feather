import Foundation
import UIKit

class OptionsManager: ObservableObject {
	static let shared = OptionsManager()

	private let _key = "signing_options"

	@Published var options: Options {
		didSet {
			saveOptions()
		}
	}

	init() {
		let defaults = Options.defaultOptions

		if let data = UserDefaults.standard.data(forKey: _key) {
			do {
				let savedDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

				let defaultData = try JSONEncoder().encode(defaults)
				var mergedDict = try JSONSerialization.jsonObject(with: defaultData) as? [String: Any] ?? [:]

				for (key, value) in savedDict {
					mergedDict[key] = value
				}

				let mergedData = try JSONSerialization.data(withJSONObject: mergedDict)
				self.options = try JSONDecoder().decode(Options.self, from: mergedData)
				return
			} catch {
				print("Failed to decode or merge options, falling back to defaults :/ \(error)")
			}
		}

		self.options = defaults

		if let encoded = try? JSONEncoder().encode(defaults) {
			UserDefaults.standard.set(encoded, forKey: _key)
		}
	}

	func saveOptions() {
		if let encoded = try? JSONEncoder().encode(options) {
			UserDefaults.standard.set(encoded, forKey: _key)
		}
	}
}

struct Options: Codable, Equatable {
	var appName: String?
	var appVersion: String?
	var appIdentifier: String?
	var appEntitlementsFile: URL?
	var appAppearance: AppAppearance
	var minimumAppRequirement: MinimumAppRequirement
	var signingOption: SigningOption

	var injectPath: InjectPath
	var injectFolder: InjectFolder
	var ppqString: String
	var ppqProtection: Bool
	var dynamicProtection: Bool
	var identifiers: [String: String]
	var displayNames: [String: String]
	var injectionFiles: [URL]
	var disInjectionFiles: [String]
	var removeFiles: [String]
	var fileSharing: Bool
	var itunesFileSharing: Bool
	var proMotion: Bool
	var gameMode: Bool
	var ipadFullscreen: Bool
	var removeURLScheme: Bool
	var removeProvisioning: Bool
	var removeWatchApp: Bool
	var removeUnusedLanguages: Bool
	var changeLanguageFilesForCustomDisplayName: Bool
	var injectIntoExtensions: Bool
	var mergeEntitlements: Bool

	var experiment_supportLiquidGlass: Bool
	var experiment_disableLiquidGlass: Bool
	var experiment_replaceSubstrateWithEllekit: Bool

	var post_installAppAfterSigned: Bool
	var post_deleteAppAfterSigned: Bool

	static let defaultOptions = Options(

		appAppearance: .default,
		minimumAppRequirement: .default,
		signingOption: .default,

		injectPath: .executable_path,
		injectFolder: .frameworks,
		ppqString: randomString(),
		ppqProtection: false,
		dynamicProtection: false,
		identifiers: [:],
		displayNames: [:],
		injectionFiles: [],
		disInjectionFiles: [],
		removeFiles: [],
		fileSharing: false,
		itunesFileSharing: false,
		proMotion: false,
		gameMode: false,
		ipadFullscreen: false,
		removeURLScheme: false,
		removeProvisioning: false,
		removeWatchApp: false,
		removeUnusedLanguages: false,
		changeLanguageFilesForCustomDisplayName: false,
		injectIntoExtensions: false,
		mergeEntitlements: false,

		experiment_supportLiquidGlass: false,
		experiment_disableLiquidGlass: false,
		experiment_replaceSubstrateWithEllekit: false,

		post_installAppAfterSigned: false,
		post_deleteAppAfterSigned: false
	)

	enum AppAppearance: String, Codable, CaseIterable, LocalizedDescribable {
		case `default`
		case light = "Light"
		case dark = "Dark"

		var localizedDescription: String {
			switch self {
			case .default: .localized("Default")
			case .light: .localized("Light")
			case .dark: .localized("Dark")
			}
		}
	}

	enum MinimumAppRequirement: String, Codable, CaseIterable, LocalizedDescribable {
		case `default`
		case v16 = "16.0"
		case v15 = "15.0"
		case v14 = "14.0"
		case v13 = "13.0"
		case v12 = "12.0"

		var localizedDescription: String {
			switch self {
			case .default: .localized("Default")
			case .v16: "16.0"
			case .v15: "15.0"
			case .v14: "14.0"
			case .v13: "13.0"
			case .v12: "12.0"
			}
		}
	}

	enum SigningOption: String, Codable, CaseIterable, LocalizedDescribable {
		case `default`
		case onlyModify

		var localizedDescription: String {
			switch self {
			case .default: .localized("Default")
			case .onlyModify: .localized("Modify")
			}
		}
	}

	enum InjectPath: String, Codable, CaseIterable, LocalizedDescribable {
		case executable_path = "@executable_path"
		case rpath = "@rpath"
	}

	enum InjectFolder: String, Codable, CaseIterable, LocalizedDescribable {
		case root = "/"
		case frameworks = "/Frameworks/"
	}

	static func randomString() -> String {
		String((0..<6).compactMap { _ in UUID().uuidString.randomElement() })
	}
}

protocol LocalizedDescribable {
	var localizedDescription: String { get }
}

extension LocalizedDescribable where Self: RawRepresentable, RawValue == String {
	var localizedDescription: String {
		let localized = NSLocalizedString(self.rawValue, comment: "")
		return localized == self.rawValue ? self.rawValue : localized
	}
}

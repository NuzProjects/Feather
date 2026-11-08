import Foundation
struct GitHubRepository: Codable, Equatable, Hashable, Identifiable {
	var id: String { slug }
	let owner: String
	let name: String
	var slug: String { "\(owner)/\(name)" }
	var webURL: URL { URL(string: "https://github.com/\(slug)")! }
	var avatarURL: URL? { URL(string: "https://github.com/\(owner).png?size=200") }
	init(_ input: String) throws {
		let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
		let url = URL(string: text.contains("://") ? text : "https://github.com/" + text)
		guard let url, url.scheme == "https", url.host?.lowercased() == "github.com", url.user == nil, url.password == nil else { throw ReleaseError.invalidRepository }
		let parts = url.path.split(separator: "/").map(String.init)
		guard parts.count >= 2 else { throw ReleaseError.invalidRepository }
		let repo = parts[1].hasSuffix(".git") ? String(parts[1].dropLast(4)) : parts[1]
		let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
		guard [parts[0], repo].allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0.unicodeScalars.allSatisfy(allowed.contains) }) else { throw ReleaseError.invalidRepository }
		owner = parts[0]; name = repo
	}
}
enum ReleaseError: LocalizedError {
	case invalidRepository, noIPA, ambiguousAsset, requestFailed(Int), invalidApp
	var errorDescription: String? {
		switch self {
		case .invalidRepository: return NSLocalizedString("Enter a GitHub repository like owner/name, or paste its link.", comment: "")
		case .noIPA: return NSLocalizedString("This repository has no releases with an IPA file.", comment: "")
		case .ambiguousAsset: return NSLocalizedString("This release has more than one IPA file. Open it from GitHub again and pick the one you want.", comment: "")
		case .requestFailed(let code) where code == 403 || code == 429: return NSLocalizedString("GitHub is limiting how often Feather can check right now. Try again in a few minutes.", comment: "")
		case .requestFailed(404): return NSLocalizedString("Couldn't find that repository. Check the name, and make sure it's public.", comment: "")
		case .requestFailed(let code) where (500...599).contains(code): return NSLocalizedString("GitHub is having trouble right now. Try again in a minute.", comment: "")
		case .requestFailed: return NSLocalizedString("Couldn't reach GitHub. Check your connection and try again.", comment: "")
		case .invalidApp: return NSLocalizedString("This IPA doesn't contain an app Feather can install.", comment: "")
		}
	}
}
struct GitHubAsset: Codable, Identifiable, Equatable {
	let id: Int64
	let name: String
	let browser_download_url: URL
	var isIPA: Bool { name.lowercased().hasSuffix(".ipa") && browser_download_url.scheme == "https" && browser_download_url.host == "github.com" }
}
struct GitHubRelease: Codable, Identifiable, Equatable {
	let id: Int64
	let tag_name: String
	let name: String?
	let draft: Bool
	let prerelease: Bool
	let published_at: String?
	let assets: [GitHubAsset]
	var body: String? = nil
	var ipaAssets: [GitHubAsset] { assets.filter(\.isIPA) }
	func matchingAsset(named original: String) -> GitHubAsset? {
		if let exact = ipaAssets.first(where: { $0.name == original }) { return exact }
		func normalized(_ name: String) -> String {
			name.lowercased().replacingOccurrences(of: #"v?\d+(?:[._-]\d+)*(?:-[a-z]+\d*)?"#, with: "", options: .regularExpression)
		}
		let matches = ipaAssets.filter { normalized($0.name) == normalized(original) }
		if matches.count == 1 { return matches[0] }
		return ipaAssets.count == 1 ? ipaAssets[0] : nil
	}
	func isNewer(than previous: GitHubRelease) -> Bool {
		guard id != previous.id, !draft, !prerelease || previous.prerelease else { return false }
		if let date = published_at, let old = previous.published_at { return date > old }
		return id > previous.id
	}
}
enum NavigatorRules {
	static let all = ["sources", "library", "certificates", "settings"]
	static func sanitize(_ items: [String]) -> [String] {
		var result: [String] = []
		for item in items where all.contains(item) && !result.contains(item) { result.append(item) }
		if !result.contains("settings") { result.append("settings") }
		return result
	}
}

struct ReplacementIdentity {
	let bundleIdentifier: String
	func apply(to info: NSMutableDictionary) {
		info["CFBundleIdentifier"] = bundleIdentifier
	}
}

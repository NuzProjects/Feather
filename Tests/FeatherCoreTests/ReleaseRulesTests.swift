import XCTest
@testable import FeatherCore
final class ReleaseRulesTests: XCTestCase {
    func testReplacementPreservesIncomingVersionAndBuild() {
        let output: NSMutableDictionary = ["CFBundleIdentifier": "new.id", "CFBundleShortVersionString": "2.4", "CFBundleVersion": "2409"]
        ReplacementIdentity(bundleIdentifier: "existing.id").apply(to: output)
        XCTAssertEqual(output["CFBundleIdentifier"] as? String, "existing.id")
        XCTAssertEqual(output["CFBundleShortVersionString"] as? String, "2.4")
        XCTAssertEqual(output["CFBundleVersion"] as? String, "2409")
    }
    func testRepositoryParsing() throws {
        XCTAssertEqual(try GitHubRepository("https://github.com/owner/app/releases/tag/v2").slug, "owner/app")
        XCTAssertEqual(try GitHubRepository("owner/app.git").slug, "owner/app")
        XCTAssertThrowsError(try GitHubRepository("https://evil.example/owner/app"))
        XCTAssertThrowsError(try GitHubRepository("https://secret@github.com/owner/app"))
    }
    func testSettingsCannotDisappear() {
        XCTAssertEqual(NavigatorRules.sanitize([]), ["settings"])
        XCTAssertEqual(NavigatorRules.sanitize(["library", "unknown", "library"]), ["library", "settings"])
    }
    func testAssetSelection() {
        let assets = [GitHubAsset(id: 1, name: "App-v2.0.ipa", browser_download_url: URL(string: "https://github.com/o/r/releases/download/v2/App.ipa")!), GitHubAsset(id: 2, name: "App-TrollStore-v2.0.ipa", browser_download_url: URL(string: "https://github.com/o/r/releases/download/v2/Troll.ipa")!)]
        let release = GitHubRelease(id: 2, tag_name: "v2", name: nil, draft: false, prerelease: false, published_at: "2026-02-01", assets: assets)
        XCTAssertEqual(release.matchingAsset(named: "App-v1.0.ipa")?.id, 1)
        XCTAssertNil(release.matchingAsset(named: "Other.ipa"))
        XCTAssertFalse(release.isNewer(than: GitHubRelease(id: 3, tag_name: "v3", name: nil, draft: false, prerelease: false, published_at: "2026-03-01", assets: assets)))
    }
}

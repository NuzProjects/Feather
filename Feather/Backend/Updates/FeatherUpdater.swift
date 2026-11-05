import Foundation
import SwiftUI

@MainActor
final class FeatherUpdater: ObservableObject {
    static let shared = FeatherUpdater()
    static let repository = try! GitHubRepository("NuzProjects/Feather")

    enum Phase: Equatable { case idle, checking, downloading, signing, ready, failed(String) }

    @Published private(set) var latest: GitHubRelease?
    @Published private(set) var phase: Phase = .idle
    @Published var signedUpdate: AnyApp?
    @Published var promptRelease: GitHubRelease?

    private let installedKey = "Updates.installedRelease"
    private let skippedKey = "Updates.skippedRelease"
    private init() {}

    var currentVersion: String {
        let info = Bundle.main.infoDictionary
        let label = (info?["FeatherVersionLabel"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let short = label ?? info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    private var installDate: Date? {
        guard let url = Bundle.main.executableURL else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    var updateAvailable: Bool {
        guard let latest else { return false }
        if let installed = UserDefaults.standard.object(forKey: installedKey) as? Int64 { return latest.id != installed }
        guard let published = latest.published_at.flatMap(ISO8601DateFormatter().date(from:)), let installDate else { return false }
        return published > installDate
    }

    var releaseNotes: String? {
        guard let body = latest?.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty else { return nil }
        return body
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("#") }
            .map { line -> String in line.hasPrefix("* ") || line.hasPrefix("- ") ? "• " + String(line.dropFirst(2)) : line }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isBusy: Bool { phase == .checking || phase == .downloading || phase == .signing }

    func check() async {
        guard !isBusy else { return }
        phase = .checking
        do {
            let releases = try await GitHubReleases.shared.releases(Self.repository)
            latest = releases.sorted { ($0.published_at ?? "") > ($1.published_at ?? "") }.first
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func checkOnLaunch() async {
        await check()
        if phase != .idle { phase = .idle; return }
        guard updateAvailable, let latest, UserDefaults.standard.object(forKey: skippedKey) as? Int64 != latest.id else { return }
        promptRelease = latest
    }

    func skip(_ release: GitHubRelease) {
        UserDefaults.standard.set(release.id, forKey: skippedKey)
    }

    func install() {
        guard !isBusy, let release = latest, let asset = release.matchingAsset(named: "Feather.ipa") else { return }
        let index = UserDefaults.standard.integer(forKey: "feather.selectedCert")
        guard let certificate = Storage.shared.getCertificate(for: index) else {
            phase = .failed("Add a certificate in Settings before updating.")
            return
        }
        phase = .downloading
        Task {
            do {
                let (temporary, response) = try await URLSession.shared.download(from: asset.browser_download_url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ReleaseError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0) }
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: folder) }
                let ipa = folder.appendingPathComponent("Feather.ipa")
                try FileManager.default.moveItem(at: temporary, to: ipa)

                let imported: Imported = try await withCheckedThrowingContinuation { continuation in
                    FR.handlePackageFile(ipa, onImported: { continuation.resume(returning: $0) }) { error in
                        if let error { continuation.resume(throwing: error) }
                    }
                }
                phase = .signing
                var options = OptionsManager.shared.options
                options.appIdentifier = Bundle.main.bundleIdentifier
                options.appName = nil
                options.appVersion = nil
                options.signingOption = .default
                let signed: Signed = try await withCheckedThrowingContinuation { continuation in
                    FR.signPackageFile(imported, using: options, icon: nil, certificate: certificate, onSigned: { continuation.resume(returning: $0) }) { error in
                        if let error { continuation.resume(throwing: error) }
                    }
                }
                Storage.shared.deleteApp(for: imported)
                UserDefaults.standard.set(release.id, forKey: installedKey)
                phase = .ready
                signedUpdate = AnyApp(base: signed)
            } catch is CancellationError {
                phase = .idle
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}

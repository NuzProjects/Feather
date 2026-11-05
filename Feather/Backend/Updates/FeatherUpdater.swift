import Foundation
import SwiftUI

/// Checks NuzProjects/Feather releases and installs a newer Feather build in place,
/// signed with the selected certificate and keeping the current bundle identifier.
@MainActor
final class FeatherUpdater: ObservableObject {
    static let shared = FeatherUpdater()
    static let repository = try! GitHubRepository("NuzProjects/Feather")

    enum Phase: Equatable { case idle, checking, downloading, signing, ready, failed(String) }

    @Published private(set) var latest: GitHubRelease?
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lastChecked: Date?
    @Published var signedUpdate: AnyApp?

    private let installedKey = "Updates.installedRelease"
    private init() {}

    var currentVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    /// When this copy of Feather was put on the device. Signing rewrites the executable, so this is never older than the build.
    private var installDate: Date? {
        guard let url = Bundle.main.executableURL else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    var updateAvailable: Bool {
        guard let latest else { return false }
        let installed = UserDefaults.standard.object(forKey: installedKey) as? Int64
        if let installed { return latest.id != installed }
        guard let published = latest.published_at.flatMap(ISO8601DateFormatter().date(from:)), let installDate else { return false }
        return published > installDate
    }

    var isBusy: Bool { phase == .checking || phase == .downloading || phase == .signing }

    func check() async {
        guard !isBusy else { return }
        phase = .checking
        do {
            let releases = try await GitHubReleases.shared.releases(Self.repository)
            latest = releases.sorted { ($0.published_at ?? "") > ($1.published_at ?? "") }.first
            lastChecked = Date()
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
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
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}

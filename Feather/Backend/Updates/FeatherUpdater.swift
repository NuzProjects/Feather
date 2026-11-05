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
        return label ?? info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var installDate: Date? {
        guard let url = Bundle.main.executableURL else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    /// "1.0.1 Beta 13" → [1, 0, 1, 13]; a final release ranks above its betas.
    static func versionKey(_ text: String) -> [Int]? {
        let parts = text.lowercased().components(separatedBy: " beta")
        let numbers = parts[0].trimmingCharacters(in: .whitespaces).split(separator: ".").compactMap { Int($0) }
        guard !numbers.isEmpty else { return nil }
        let padded = numbers + Array(repeating: 0, count: max(0, 3 - numbers.count))
        guard parts.count > 1 else { return padded + [Int.max] }
        return padded + [Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 1]
    }

    var updateAvailable: Bool {
        guard let latest else { return false }
        if let new = Self.versionKey(Self.displayName(latest)), let current = Self.versionKey(currentVersion) {
            return new.lexicographicallyPrecedes(current) == false && new != current
        }
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

    var plainReleaseNotes: String? {
        releaseNotes?.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
    }

    static func displayName(_ release: GitHubRelease) -> String {
        let name = release.name ?? release.tag_name
        return name.hasPrefix("Update ") ? String(name.dropFirst(7)) : name
    }

    var isBusy: Bool { phase == .checking || phase == .downloading || phase == .signing }

    func check() async {
        guard !isBusy else { return }
        phase = .checking
        do {
            // Official versions only get official releases; betas get everything.
            let onBeta = currentVersion.localizedCaseInsensitiveContains("beta")
            let releases = try await GitHubReleases.shared.releases(Self.repository).filter { onBeta || !$0.prerelease }
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
            var importedCopy: Imported?
            defer { if let importedCopy, importedCopy.managedObjectContext != nil { Storage.shared.deleteApp(for: importedCopy) } }
            do {
                let (temporary, response) = try await URLSession.shared.download(from: asset.browser_download_url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ReleaseError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0) }
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: folder) }
                let ipa = folder.appendingPathComponent("Feather.ipa")
                try FileManager.default.moveItem(at: temporary, to: ipa)

                // Replace an earlier Feather import, or pass "" so no "Replace Imported App?" prompt appears.
                let previous = ((try? Storage.shared.context.fetch(Imported.fetchRequest())) ?? []).first { $0.identifier == Bundle.main.bundleIdentifier }
                let imported: Imported = try await withCheckedThrowingContinuation { continuation in
                    FR.handlePackageFile(ipa, replacingImport: previous?.uuid ?? "", onImported: { continuation.resume(returning: $0) }) { error in
                        if let error { continuation.resume(throwing: error) }
                    }
                }
                importedCopy = imported
                phase = .signing
                // Plain options so the user's tweaks and custom settings never go into Feather itself.
                var options = Options.defaultOptions
                options.appIdentifier = Bundle.main.bundleIdentifier
                options.appName = nil
                options.appVersion = nil
                options.signingOption = .default
                let signed: Signed = try await withCheckedThrowingContinuation { continuation in
                    FR.signPackageFile(imported, using: options, icon: nil, certificate: certificate, onSigned: { continuation.resume(returning: $0) }) { error in
                        if let error { continuation.resume(throwing: error) }
                    }
                }
                // Keep only the newest signed copy of Feather in Library.
                for old in (try? Storage.shared.context.fetch(Signed.fetchRequest())) ?? [] where old.identifier == signed.identifier && old.uuid != signed.uuid {
                    Storage.shared.deleteApp(for: old)
                }
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

import NimbleExtensions
import SwiftUI
import CoreData
import UserNotifications
import BackgroundTasks

struct GitHubTracking: Codable {
    let repository: GitHubRepository
    let release: GitHubRelease
    let asset: GitHubAsset
    var notifications: Bool
}

@MainActor
final class GitHubReleases: ObservableObject {
    static let shared = GitHubReleases()
    static let refreshID = "dev.madebynuz.dev.feather.release-refresh"
    @Published var updates: [String: GitHubTracking] = [:]
    @Published var busy: Set<String> = []
    @Published var lastError: String?
    private(set) var tracking: [String: GitHubTracking] = [:]
    private var checking = false
    private var lastCheck = Date.distantPast
    private var notified: Set<String>
    private init() {
        if let data = UserDefaults.standard.data(forKey: "GitHub.tracking"), let saved = try? JSONDecoder().decode([String: GitHubTracking].self, from: data) { tracking = saved }
        notified = Set(UserDefaults.standard.stringArray(forKey: "GitHub.notified") ?? [])
    }
    func save() {
        if let data = try? JSONEncoder().encode(tracking) { UserDefaults.standard.set(data, forKey: "GitHub.tracking") }
    }
    func copy(from old: String?, to new: String) {
        if let old, let value = tracking[old] { tracking[new] = value; save() }
    }
    func remove(_ uuid: String?) {
        guard let uuid else { return }; tracking.removeValue(forKey: uuid); updates.removeValue(forKey: uuid); save()
    }
    func allApps() -> [AppInfoPresentable] {
        let signed = (try? Storage.shared.context.fetch(Signed.fetchRequest())) ?? []
        let imported = (try? Storage.shared.context.fetch(Imported.fetchRequest())) ?? []
        return signed.map { $0 as AppInfoPresentable } + imported.map { $0 as AppInfoPresentable }
    }
    func releases(_ repository: GitHubRepository) async throws -> [GitHubRelease] {
        let url = URL(string: "https://api.github.com/repos/\(repository.slug)/releases?per_page=30")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MadeByNuz-Feather", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw ReleaseError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0) }
        return try JSONDecoder().decode([GitHubRelease].self, from: data).filter { !$0.draft && !$0.ipaAssets.isEmpty }
    }
    @discardableResult
    func check(force: Bool = false) async -> Bool {
        guard !checking, force || Date().timeIntervalSince(lastCheck) > 1800 else { return true }
        checking = true; defer { checking = false }
        var cache: [GitHubRepository: [GitHubRelease]] = [:]
        let apps = allApps()
        let live = Set(apps.compactMap(\.uuid))
        tracking = tracking.filter { live.contains($0.key) }; save()
        var failed = false
        for (uuid, old) in tracking {
            if Task.isCancelled { break }
            do {
                let values: [GitHubRelease]
                if let saved = cache[old.repository] { values = saved } else { values = try await releases(old.repository); cache[old.repository] = values }
                guard let release = values.filter({ $0.isNewer(than: old.release) }).sorted(by: { ($0.published_at ?? "") > ($1.published_at ?? "") }).first,
                      let asset = release.matchingAsset(named: old.asset.name) else { updates.removeValue(forKey: uuid); continue }
                let update = GitHubTracking(repository: old.repository, release: release, asset: asset, notifications: old.notifications)
                updates[uuid] = update
                let notificationID = "\(old.repository.slug):\(asset.id)"
                if old.notifications, !notified.contains(notificationID), let app = apps.first(where: { $0.uuid == uuid }) {
                    if await notify(app: app, update: update, id: notificationID) {
                        notified.insert(notificationID)
                        UserDefaults.standard.set(Array(notified), forKey: "GitHub.notified")
                    }
                }
            } catch { failed = true; lastError = error.localizedDescription }
        }
        if !failed { lastCheck = Date() }
        return !failed && !Task.isCancelled
    }
    private func notify(app: AppInfoPresentable, update: GitHubTracking, id: String) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return false }
        let content = UNMutableNotificationContent()
        content.title = "\(app.name ?? "App") has a new update!"
        content.body = update.release.name ?? update.release.tag_name
        content.sound = .default
        content.userInfo = ["appUUID": app.uuid ?? ""]
        if let directory = Storage.shared.getAppDirectory(for: app), let data = iconTest(directory)?.pngData() {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("UpdateIcons", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent(UUID().uuidString + ".png")
            if (try? data.write(to: file)) != nil, let attachment = try? UNNotificationAttachment(identifier: "icon", url: file) { content.attachments = [attachment] }
        }
        do { try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil)); return true } catch { return false }
    }
    func importAsset(_ selection: GitHubTracking, replacing old: AppInfoPresentable? = nil) async throws {
        let oldUUID = old?.uuid
        let oldIdentifier = old?.identifier
        let oldWasSigned = old?.isSigned == true
        let oldOptions = SigningHistory.shared.options(for: oldUUID)
        let oldCertificate = old.flatMap { Storage.shared.getCertificate(from: $0) }
        let previous = oldUUID.flatMap { tracking[$0] }
        let replacementImport = oldWasSigned ? allApps().first(where: {
            guard !$0.isSigned, let uuid = $0.uuid, let tracked = tracking[uuid], let previous else { return false }
            return tracked.repository == previous.repository && tracked.release.id == previous.release.id && tracked.asset.id == previous.asset.id
        })?.uuid : oldUUID
        let key = oldUUID ?? selection.repository.slug
        guard !busy.contains(key) else { return }
        busy.insert(key); defer { busy.remove(key) }
        let lease = UpdateBackgroundLease()
        defer { lease.end() }
        let (temporary, response) = try await URLSession.shared.download(from: selection.asset.browser_download_url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ReleaseError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0) }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let ipa = folder.appendingPathComponent("download.ipa")
        try FileManager.default.moveItem(at: temporary, to: ipa)
        let imported: Imported = try await withCheckedThrowingContinuation { continuation in
            FR.handlePackageFile(ipa, replacingImport: replacementImport, onImported: { app in continuation.resume(returning: app) }) { error in
                if let error { continuation.resume(throwing: error) }
            }
        }
        guard let uuid = imported.uuid else { throw ReleaseError.invalidApp }
        tracking[uuid] = selection; save()
        guard let old else { return }
        if let certificate = oldCertificate {
            var options = oldOptions ?? OptionsManager.shared.options
            options.appIdentifier = oldIdentifier
            options.appVersion = nil
            options.signingOption = .default
            let signed: Signed = try await withCheckedThrowingContinuation { continuation in
                FR.signPackageFile(imported, using: options, icon: nil, certificate: certificate, onSigned: { app in continuation.resume(returning: app) }) { error in
                    if let error { continuation.resume(throwing: error) }
                }
            }
            if oldWasSigned { Storage.shared.deleteApp(for: old) }
            NotificationCenter.default.post(name: .init("Feather.installApp"), object: signed)
        } else {
            NotificationCenter.default.post(name: .init("Feather.signApp"), object: AnyApp(base: imported, replacementUUID: oldWasSigned ? oldUUID : nil, preferredIdentifier: oldIdentifier))
        }
    }
    func update(_ app: AppInfoPresentable) {
        guard let uuid = app.uuid, let update = updates[uuid] else { return }
        Task {
            do { try await importAsset(update, replacing: app) }
            catch { UIAlertController.showAlertWithOk(title: "Update Failed", message: error.localizedDescription) }
        }
    }
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: refreshID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1800)
        try? BGTaskScheduler.shared.submit(request)
    }
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshID, using: nil) { task in
            let work = Task { @MainActor in
                schedule()
                let success = await shared.check(force: true)
                task.setTaskCompleted(success: success)
            }
            task.expirationHandler = { work.cancel() }
        }
    }
}

@MainActor
private final class UpdateBackgroundLease {
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    init() {
        identifier = UIApplication.shared.beginBackgroundTask(withName: "GitHub IPA") { [weak self] in
            Task { @MainActor in self?.end() }
        }
    }
    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}

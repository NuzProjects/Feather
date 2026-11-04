import UIKit
import CoreData

@MainActor
final class ReplacementCoordinator {
    static let shared = ReplacementCoordinator()
    private var importDialogOpen = false
    func duplicateImport(name: String?, replacing uuid: String?) async throws -> Imported? {
        while importDialogOpen { try await Task.sleep(nanoseconds: 100_000_000) }
        importDialogOpen = true
        defer { importDialogOpen = false }
        let apps = (try? Storage.shared.context.fetch(Imported.fetchRequest())) ?? []
        if let uuid { return apps.first { $0.uuid == uuid } }
        guard let name, let existing = apps.sorted(by: { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }).first(where: { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame }) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let alert = UIAlertController(title: "Replace Imported App?", message: "An imported app named \(name) already exists. Replace it with this IPA or keep both?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Replace", style: .destructive) { _ in continuation.resume(returning: existing) })
            alert.addAction(UIAlertAction(title: "Keep Both", style: .default) { _ in continuation.resume(returning: nil) })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in continuation.resume(throwing: CancellationError()) })
            guard let presenter = UIApplication.topViewController() else { continuation.resume(throwing: CancellationError()); return }
            presenter.present(alert, animated: true)
        }
    }
    func requestSigning(_ app: AppInfoPresentable, present: @escaping (AnyApp) -> Void) {
        let apps = (try? Storage.shared.context.fetch(Signed.fetchRequest())) ?? []
        guard let existing = apps.first(where: { $0.identifier == app.identifier && app.identifier != nil }) ?? apps.first(where: { $0.name?.localizedCaseInsensitiveCompare(app.name ?? "") == .orderedSame }) else { present(AnyApp(base: app)); return }
        UIAlertController.showAlertWithCancel(title: "Sign Over Existing App?", message: "Use \(existing.identifier ?? "the existing identifier") to replace \(existing.name ?? "this app")? The new IPA keeps its own version.", actions: [
            UIAlertAction(title: "Sign Over", style: .default) { _ in present(AnyApp(base: app, replacementUUID: existing.uuid, preferredIdentifier: existing.identifier)) },
            UIAlertAction(title: "Sign Separately", style: .default) { _ in present(AnyApp(base: app)) }
        ])
    }
}

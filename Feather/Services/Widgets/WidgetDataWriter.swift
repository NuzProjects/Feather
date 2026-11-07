import Combine
import CoreData
import UIKit
import WidgetKit

@MainActor
final class WidgetDataWriter {
	static let shared = WidgetDataWriter()

	private var cancellables: Set<AnyCancellable> = []
	private var lastWritten: WidgetSnapshot?
	private var iconCache: [String: Data] = [:]

	func start() {
		guard cancellables.isEmpty else { return }
		NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
			.merge(with: NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification))
			.debounce(for: .seconds(1.5), scheduler: DispatchQueue.main)
			.sink { [weak self] _ in self?.refresh() }
			.store(in: &cancellables)
		refresh()
	}

	func refresh() {
		var snapshot = _makeSnapshot()
		if var previous = lastWritten {
			previous.updated = snapshot.updated
			guard previous != snapshot else { return }
		}
		snapshot.updated = Date()
		guard WidgetSnapshotStore.write(snapshot) else { return }
		lastWritten = snapshot
		WidgetCenter.shared.reloadAllTimelines()
	}

	private func _makeSnapshot() -> WidgetSnapshot {
		let context = Storage.shared.context

		let signedRequest: NSFetchRequest<Signed> = Signed.fetchRequest()
		signedRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Signed.date, ascending: false)]
		let signed = (try? context.fetch(signedRequest)) ?? []

		let importedRequest: NSFetchRequest<Imported> = Imported.fetchRequest()
		let importedCount = (try? context.count(for: importedRequest)) ?? 0

		let recent = signed.prefix(4).map { app in
			WidgetSnapshot.App(name: app.name ?? "App", version: app.version, date: app.date, icon: _icon(for: app))
		}

		var certificate: WidgetSnapshot.Certificate?
		if let pair = Storage.shared.getCertificate(for: UserDefaults.standard.integer(forKey: "feather.selectedCert")) {
			certificate = .init(name: pair.nickname ?? "Certificate", expiration: pair.expiration, revoked: pair.revoked)
		}

		return WidgetSnapshot(
			tint: UserDefaults.standard.string(forKey: "Feather.userTintColor") ?? "#848ef9",
			certificate: certificate,
			signedCount: signed.count,
			importedCount: importedCount,
			recent: Array(recent),
			updated: Date()
		)
	}

	private func _icon(for app: Signed) -> Data? {
		guard let uuid = app.uuid else { return nil }
		if let cached = iconCache[uuid] { return cached }
		guard
			let directory = Storage.shared.getAppDirectory(for: app),
			let image = iconTest(directory)
		else { return nil }
		let size = CGSize(width: 120, height: 120)
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
			image.draw(in: CGRect(origin: .zero, size: size))
		}
		let data = resized.pngData()
		iconCache[uuid] = data
		return data
	}
}

import SwiftUI
import UniformTypeIdentifiers
import NimbleViews

struct DataTransferView: View {
	@State private var busy = false
	@State private var picker: TransferPicker.Kind?
	@State private var exportFolder: URL?
	@State private var message: String?
	var body: some View {
		NBList("Backup & Transfer") {
			Section {
				Button("Back Up Everything", systemImage: "square.and.arrow.up") { export(includeApps: true) }
				Button("Back Up Without Apps", systemImage: "square.and.arrow.up.on.square") { export(includeApps: false) }
				Button("Restore Backup", systemImage: "square.and.arrow.down") { picker = .import }
			} footer: { Text("Everything includes your apps, certificates, sources and settings. Without Apps keeps only certificates, sources and settings, so the backup stays small. Restoring adds to what's already here.") }
			if busy { ProgressView("Transferring…") }
		}
		.symbolVariant(.fill)
		.disabled(busy)
		.sheet(item: $picker) { kind in
			TransferPicker(kind: kind, exportFolder: exportFolder) { url in
				picker = nil
				guard kind == .import, let url else { return }
				Task {
					busy = true; defer { busy = false }
					do {
						let count = try await FeatherTransfer.restore(url)
						message = "Restored \(count) items. Close and reopen Feather to load the restored settings."
					} catch { message = error.localizedDescription }
				}
			}
		}
		.alert("Backup & Transfer", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
	}
	private func export(includeApps: Bool) {
		Task {
			busy = true; defer { busy = false }
			do { exportFolder = try await FeatherTransfer.export(includeApps: includeApps); picker = .export }
			catch { message = error.localizedDescription }
		}
	}
}

private struct TransferPicker: UIViewControllerRepresentable {
	enum Kind: String, Identifiable { case `import`, export; var id: String { rawValue } }
	let kind: Kind
	let exportFolder: URL?
	let completion: (URL?) -> Void
	func makeCoordinator() -> Coordinator { Coordinator(completion) }
	func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
		let picker: UIDocumentPickerViewController
		if kind == .export, let exportFolder { picker = UIDocumentPickerViewController(forExporting: [exportFolder], asCopy: true) }
		else { picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false) }
		picker.delegate = context.coordinator
		picker.allowsMultipleSelection = false
		return picker
	}
	func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
	final class Coordinator: NSObject, UIDocumentPickerDelegate {
		let completion: (URL?) -> Void
		init(_ completion: @escaping (URL?) -> Void) { self.completion = completion }
		func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { completion(urls.first) }
		func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { completion(nil) }
	}
}

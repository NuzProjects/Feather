import SwiftUI
import UniformTypeIdentifiers

struct DataTransferView: View {
    @State private var busy = false
    @State private var picker: TransferPicker.Kind?
    @State private var exportFolder: URL?
    @State private var message: String?
    var body: some View {
        Form {
            Section {
                Button("Export Data", systemImage: "square.and.arrow.up") { export(includeApps: true) }
                Button("Import Data", systemImage: "square.and.arrow.down") { picker = .import }
            }
            Section("Old Feather Installer") {
                Button("Import Old Feather Backup", systemImage: "arrow.down.doc") { picker = .import }
                if let helper = Bundle.main.url(forResource: "LegacyTransfer", withExtension: "ipa") {
                    Button("Export Transfer Installer", systemImage: "square.and.arrow.up") { exportFolder = helper; picker = .export }
                } else {
                    Link("Get Transfer Installer", destination: URL(string: "https://github.com/NuzProjects/Feather/releases/download/iphone-test-build-14/Feather-Transfer.ipa")!)
                }
            }
            if busy { ProgressView("Transferring…") }
        }
        .symbolVariant(.fill)
        .navigationTitle("Transfer Data")
        .disabled(busy)
        .sheet(item: $picker) { kind in
            TransferPicker(kind: kind, exportFolder: exportFolder) { url in
                picker = nil
                guard kind == .import, let url else { return }
                Task {
                    busy = true; defer { busy = false }
                    do {
                        let count = try await FeatherTransfer.restore(url)
                        message = "Copied \(count) records. Close and reopen Feather to load transferred preferences. The original app is unchanged."
                    } catch { message = error.localizedDescription }
                }
            }
        }
        .alert("Transfer Data", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
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

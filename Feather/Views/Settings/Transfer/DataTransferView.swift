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
                Button("Export a Copy", systemImage: "square.and.arrow.up") {
                    Task {
                        busy = true; defer { busy = false }
                        do { exportFolder = try await FeatherTransfer.export(); picker = .export }
                        catch { message = error.localizedDescription }
                    }
                }
                Button("Import Feather Backup", systemImage: "square.and.arrow.down") { picker = .import }
            } footer: { Text("Copies apps, certificates, sources, and preferences. The original copy stays intact. Existing apps and files in this copy are kept when merging.") }
            Section {
                Text("To transfer from regular Feather, use the optional transfer helper with the exact bundle ID and signing identity of your installed Feather. Install over it without deleting it, then export a copy here and import that backup in the new app.")
            }
            Section { Text("Backups include certificates and their passwords. Keep the backup private.").foregroundStyle(.secondary) }
            if busy { ProgressView("Transferring…") }
        }
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

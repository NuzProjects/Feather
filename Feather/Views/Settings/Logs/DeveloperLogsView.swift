import SwiftUI
import NimbleViews

// MARK: - View
struct DeveloperLogsView: View {
	@State private var _sessions: [URL] = []
	@State private var _crashes: [URL] = []
	@State private var _isExporting = false
	@State private var _saveFile: _ExportFile?
	@State private var _isClearConfirming = false

	private let _log = DevLog.shared

	// MARK: Body
	var body: some View {
		NBList("Developer Logs") {
			Section {
				Button("Export Logs", systemImage: "square.and.arrow.up") {
					_export { UIActivityViewController.show(activityItems: [$0]) }
				}
				Button("Save to Files", systemImage: "arrow.down.doc") {
					_export { _saveFile = _ExportFile(url: $0) }
				}
			} footer: {
				Text("Exports one text file with your device and app version, crash reports, and logs from the last 10 launches. Attach it when you report a bug. Logs stay on this device until you export them.")
			}

			NBSection("Crashes", secondary: _crashes.isEmpty ? nil : "\(_crashes.count)") {
				if _crashes.isEmpty {
					Label("No crashes recorded", systemImage: "checkmark.seal")
						.foregroundStyle(.secondary)
				} else {
					ForEach(_crashes, id: \.self) { url in
						NavigationLink(destination: LogFileView(url: url, title: _title(for: url))) {
							_row(for: url, icon: url.pathExtension == "json" ? "stethoscope" : "exclamationmark.triangle", tint: .red, subtitle: _crashReason(url))
						}
					}
				}
			} footer: {
				Text("Includes crashes caught by Feather and diagnostic reports from iOS, which can arrive up to a day later.")
			}

			NBSection("Sessions") {
				ForEach(Array(_sessions.enumerated()), id: \.element) { index, url in
					NavigationLink(destination: LogFileView(url: url, title: _title(for: url), systemLog: _log.systemLog(for: url))) {
						_row(
							for: url,
							icon: index == 0 ? "record.circle" : "doc.text",
							tint: index == 0 ? .accentColor : .secondary,
							subtitle: index == 0 ? "Current session · \(_size(url))" : _size(url)
						)
					}
				}
			} footer: {
				Text("Each launch gets its own log with signing, install, download and update errors, plus Feather's system log.")
			}

			Section {
				Button("Clear Logs", systemImage: "trash", role: .destructive) {
					_isClearConfirming = true
				}
				.foregroundStyle(.red)
			}
		}
		.disabled(_isExporting)
		.overlay { if _isExporting { ProgressView() } }
		.onAppear(perform: _reload)
		.refreshable { _reload() }
		.sheet(item: $_saveFile) { file in
			FileExportPicker(url: file.url) { _saveFile = nil }
				.ignoresSafeArea()
		}
		.confirmationDialog("Clear all logs and crash reports?", isPresented: $_isClearConfirming, titleVisibility: .visible) {
			Button("Clear Logs", role: .destructive) {
				_log.clear()
				_reload()
			}
		}
	}
}

// MARK: - Extension: View
extension DeveloperLogsView {
	@ViewBuilder
	private func _row(for url: URL, icon: String, tint: Color, subtitle: String) -> some View {
		HStack(spacing: 12) {
			Image(systemName: icon)
				.font(.title3)
				.foregroundStyle(tint)
				.frame(width: 28)
			VStack(alignment: .leading, spacing: 2) {
				Text(_title(for: url))
				Text(subtitle)
					.font(.footnote)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
		}
	}

	private func _reload() {
		_sessions = _log.sessions
		_crashes = _log.crashes
	}

	private func _export(_ handler: @escaping (URL) -> Void) {
		_isExporting = true
		Task {
			let url = await _log.exportBundle()
			await MainActor.run {
				_isExporting = false
				if let url { handler(url) } else {
					UIAlertController.showAlertWithOk(title: .localized("Error"), message: "Couldn't create the log file.")
				}
			}
		}
	}

	private func _date(for url: URL) -> Date? {
		try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
	}

	private func _title(for url: URL) -> String {
		guard let date = _date(for: url) else { return url.lastPathComponent }
		return date.formatted(date: .abbreviated, time: .shortened)
	}

	private func _size(_ url: URL) -> String {
		let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
		return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
	}

	private func _crashReason(_ url: URL) -> String {
		if url.pathExtension == "json" { return "iOS diagnostic report" }
		guard let text = try? String(contentsOf: url, encoding: .utf8) else { return "Crash" }
		let line = text.components(separatedBy: "\n").first { $0.contains(CrashTrap.marker) } ?? "Crash"
		return line
			.replacingOccurrences(of: CrashTrap.marker + ": ", with: "")
			.replacingOccurrences(of: " ***", with: "")
	}
}

private struct _ExportFile: Identifiable {
	let url: URL
	var id: URL { url }
}

// MARK: - Save to Files
struct FileExportPicker: UIViewControllerRepresentable {
	let url: URL
	let completion: () -> Void

	func makeCoordinator() -> Coordinator { Coordinator(completion) }

	func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
		let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
		picker.delegate = context.coordinator
		return picker
	}

	func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

	final class Coordinator: NSObject, UIDocumentPickerDelegate {
		let completion: () -> Void
		init(_ completion: @escaping () -> Void) { self.completion = completion }
		func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { completion() }
		func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { completion() }
	}
}

//
//  UIKitFileImporter.swift
//  Feather
//
//  Created by samara on 23.04.2025.
//

import SwiftUI
import UniformTypeIdentifiers

public struct FileImporterRepresentableView: UIViewControllerRepresentable {
	public var allowedContentTypes: [UTType]
	public var allowsMultipleSelection: Bool = false
	public var onDocumentsPicked: ([URL]) -> Void
	
	public init(
		allowedContentTypes: [UTType],
		allowsMultipleSelection: Bool = false,
		onDocumentsPicked: @escaping ([URL]) -> Void
	) {
		self.allowedContentTypes = allowedContentTypes
		self.allowsMultipleSelection = allowsMultipleSelection
		self.onDocumentsPicked = onDocumentsPicked
	}
	
	static var lastFolder: URL? {
		get { UserDefaults.standard.url(forKey: "NBFileImporter.lastFolder") }
		set { UserDefaults.standard.set(newValue, forKey: "NBFileImporter.lastFolder") }
	}

	public func makeCoordinator() -> Coordinator {
		Coordinator(onDocumentsPicked: onDocumentsPicked)
	}
	
	public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
		let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: false)
		if let folder = Self.lastFolder { picker.directoryURL = folder }
		picker.delegate = context.coordinator
		picker.allowsMultipleSelection = allowsMultipleSelection
		return picker
	}
	
	public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
	
	@MainActor
	public class Coordinator: NSObject, UIDocumentPickerDelegate {
		var onDocumentsPicked: ([URL]) -> Void
		
		init(onDocumentsPicked: @escaping ([URL]) -> Void) {
			self.onDocumentsPicked = onDocumentsPicked
		}
		
		public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
			if let folder = urls.first?.deletingLastPathComponent() { FileImporterRepresentableView.lastFolder = folder }
			let callback = _Callback(onDocumentsPicked)
			DispatchQueue.global(qos: .userInitiated).async {
				let copies = Coordinator.copies(of: urls)
				DispatchQueue.main.async { callback.run(copies) }
			}
		}

		private final class _Callback: @unchecked Sendable {
			let run: ([URL]) -> Void
			init(_ run: @escaping ([URL]) -> Void) { self.run = run }
		}

		nonisolated private static func copies(of urls: [URL]) -> [URL] {
			urls.compactMap { url -> URL? in
				let scoped = url.startAccessingSecurityScopedResource()
				defer { if scoped { url.stopAccessingSecurityScopedResource() } }
				let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
				let copy = folder.appendingPathComponent(url.lastPathComponent)
				do {
					try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
					try FileManager.default.copyItem(at: url, to: copy)
					return copy
				} catch {
					return nil
				}
			}
		}
		
		public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
			onDocumentsPicked([])
		}
	}
}

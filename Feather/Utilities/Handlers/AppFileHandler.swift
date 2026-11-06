//
//  IPAHandler.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import Foundation
import Zip
import SwiftUI

final class AppFileHandler: NSObject, @unchecked Sendable {
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	var resultUUID: String { _uuid }
	private let _uniqueWorkDir: URL
	var uniqueWorkDirPayload: URL?

	private var _ipa: URL
	private let _install: Bool
	private let _download: Download?
	private let _sourceProvenance: SourceAppProvenance?
	private let progressID: UUID?
	
	init(
		file ipa: URL,
		install: Bool = false,
		download: Download? = nil,
		sourceProvenance: SourceAppProvenance? = nil,
        progressID: UUID? = nil
	) {
		self.progressID = progressID
		self._ipa = ipa
		self._install = install
		self._download = download
		self._sourceProvenance = sourceProvenance ?? download?.sourceProvenance
		self._uniqueWorkDir = _fileManager.temporaryDirectory
			.appendingPathComponent("FeatherImport_\(_uuid)", isDirectory: true)
		
		super.init()
	}
	
	func copy() async throws {
		try _fileManager.createDirectoryIfNeeded(at: _uniqueWorkDir)
		
		let destinationURL = _uniqueWorkDir.appendingPathComponent(_ipa.lastPathComponent)

		try _fileManager.removeFileIfNeeded(at: destinationURL)
		
		try _fileManager.copyItem(at: _ipa, to: destinationURL)
		_ipa = destinationURL
	}
	
	func extract() async throws {
		if _ipa.pathExtension == "ipa" {
			Zip.addCustomFileExtension("ipa")
		}
		if _ipa.pathExtension == "tipa" {
			Zip.addCustomFileExtension("tipa")
		}
		
		let download = self._download
		
		try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .utility).async {
				do {
					try Zip.unzipFile(
						self._ipa,
						destination: self._uniqueWorkDir,
						overwrite: true,
						password: nil,
						progress: { progress in
                            Task { @MainActor in ImportProgress.shared.update(self.progressID, fraction: 0.1 + progress * 0.7) }
							if let download = download {
								DispatchQueue.main.async {
									download.unpackageProgress = progress
									
									#if !targetEnvironment(macCatalyst)
									if #available(iOS 26.0, *) {
										BackgroundTaskManager.shared.updateProgress(for: download.id, progress: download.overallProgress)
									}
									#endif
								}
							}
						}
					)
					
					self.uniqueWorkDirPayload = self._uniqueWorkDir.appendingPathComponent("Payload")
					continuation.resume()
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}
	
	func move() async throws {
		guard let payloadURL = uniqueWorkDirPayload else {
			throw ImportedFileHandlerError.payloadNotFound
		}
		
		let destinationURL = try await _directory()
		
		guard _fileManager.fileExists(atPath: payloadURL.path) else {
			throw ImportedFileHandlerError.payloadNotFound
		}
		
		// The Unsigned folder may have been removed by Reset; recreate it so imports keep working.
		try _fileManager.createDirectoryIfNeeded(at: destinationURL.deletingLastPathComponent())
		try _fileManager.moveItem(at: payloadURL, to: destinationURL)
		
		try? _fileManager.removeItem(at: _uniqueWorkDir)
	}
	
	func addToDatabase(replacing uuid: String? = nil) async throws {
        let app = try await _directory()
        guard let appURL = _fileManager.getPath(in: app, for: "app"), let bundle = Bundle(url: appURL), bundle.bundleIdentifier != nil else { throw ReleaseError.invalidApp }
        try await ReplacementCoordinator.shared.commitImport(name: bundle.name, replacing: uuid) { existing in
            Storage.shared.addImported(uuid: _uuid, source: _sourceProvenance?.sourceRepositoryURL, appName: bundle.name, appIdentifier: bundle.bundleIdentifier, appVersion: bundle.version, appIcon: bundle.iconFileName) { _ in }
            if let provenance = _sourceProvenance { Storage.shared.addSourceMetadata(for: _uuid, kind: .imported, provenance: provenance) }
            do { try Storage.shared.context.save() }
            catch { Storage.shared.context.rollback(); throw error }
            if let existing { Storage.shared.deleteApp(for: existing) }
        }
    }

	private func _directory() async throws -> URL {
		// Documents/Feather/Unsigned/\(UUID)
		_fileManager.unsigned(_uuid)
	}
	
	func clean() async throws {
		try _fileManager.removeFileIfNeeded(at: _uniqueWorkDir)
	}
}

private enum ImportedFileHandlerError: LocalizedError {
	case payloadNotFound

	var errorDescription: String? {
		switch self {
		case .payloadNotFound: "This file doesn't contain an app. Make sure it's an .ipa or .tipa file, or try downloading it again."
		}
	}
}

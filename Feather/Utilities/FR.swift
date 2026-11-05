//
//  FR.swift
//  Feather
//
//  Created by samara on 22.04.2025.
//

import Foundation.NSURL
import UIKit.UIImage
import ZsignC
import NimbleJSON
import AltSourceKit
import IDeviceSwift

enum FR {
	static func handlePackageFile(
		_ ipa: URL,
		download: Download? = nil,
		sourceProvenance: SourceAppProvenance? = nil,
		replacingImport: String? = nil,
		progressID: UUID? = nil,
		onImported: ((Imported) -> Void)? = nil,
		completion: @escaping (Error?) -> Void
	) {
		Task.detached {
            let importID = await MainActor.run { progressID ?? (download == nil ? ImportProgress.shared.begin(ipa.lastPathComponent) : nil) }
			let handler = AppFileHandler(
				file: ipa,
				download: download,
				sourceProvenance: sourceProvenance,
                progressID: importID
			)
			
			do {
				try await handler.copy()
				await ImportProgress.shared.update(importID, fraction: 0.1)
                try await handler.extract()
                if let payload = handler.uniqueWorkDirPayload, let directory = FileManager.default.getPath(in: payload, for: "app") {
                    let name = Bundle(url: directory)?.name
                    let icon = iconTest(directory)
                    await MainActor.run {
                        ImportProgress.shared.update(importID, fraction: 0.85, name: name, icon: icon)
                        download?.displayName = name; download?.appIcon = icon
                    }
                }
				try await handler.move()
				try await handler.addToDatabase(replacing: replacingImport)
				try? await handler.clean()
				await MainActor.run {
					guard let imported = try? Storage.shared.context.fetch(Imported.fetchRequest()).first(where: { $0.uuid == handler.resultUUID }) else { ImportProgress.shared.finish(importID, success: false); completion(ReleaseError.invalidApp); return }
                    ImportProgress.shared.finish(importID, success: true)
                    onImported?(imported)
					completion(nil)
				}
			} catch {
				try? await handler.clean()
				try? FileManager.default.removeItem(at: FileManager.default.unsigned(handler.resultUUID))
				await MainActor.run {
					ImportProgress.shared.finish(importID, success: false)
					completion(error)
				}
			}
		}
	}
	
	static func signPackageFile(
		_ app: AppInfoPresentable,
		using options: Options,
		icon: UIImage?,
		certificate: CertificatePair?,
		onSigned: ((Signed) -> Void)? = nil,
		completion: @escaping (Error?) -> Void
	) {
		Task.detached {
            let appIcon = await MainActor.run { Storage.shared.getAppDirectory(for: app) }.flatMap { iconTest($0) }
            let job = await MainActor.run { SigningProgress.shared.begin(name: app.name ?? "App", icon: appIcon) }
            let handler = SigningHandler(app: app, options: options, progressID: job)
			handler.appCertificate = certificate
			handler.appIcon = icon
			
			do {
				if options.signingOption == .default {
					try await MainActor.run { try SigningFileHandlerError.check(certificate) }
				}
				try await handler.copy()
				if await SigningProgress.shared.isCancelled(job) { throw CancellationError() }
				await SigningProgress.shared.stage(job, .preparing)
				try await handler.modify()
				try? await handler.clean()
				await MainActor.run {
					guard let signed = try? Storage.shared.context.fetch(Signed.fetchRequest()).first(where: { $0.uuid == handler.resultUUID }) else { SigningProgress.shared.finish(job, success: false); completion(ReleaseError.invalidApp); return }
					if SigningProgress.shared.isCancelled(job) {
						Storage.shared.deleteApp(for: signed)
						completion(CancellationError())
						return
					}
                    SigningProgress.shared.finish(job, success: true)
                    onSigned?(signed)
					completion(nil)
				}
			} catch {
				try? await handler.clean()
                try? FileManager.default.removeItem(at: FileManager.default.signed(handler.resultUUID))
				await MainActor.run {
					SigningProgress.shared.finish(job, success: false)
					completion(error)
				}
			}
		}
	}
	
	static func handleCertificateFiles(
		p12URL: URL,
		provisionURL: URL,
		p12Password: String,
		certificateName: String = "",
		isDefault: Bool = false,
		completion: @escaping (Error?) -> Void
	) {
		Task.detached {
			let handler = CertificateFileHandler(
				key: p12URL,
				provision: provisionURL,
				password: p12Password,
				nickname: certificateName.isEmpty ? nil : certificateName,
				isDefault: isDefault
			)
			
			do {
				try await handler.copy()
				try await handler.addToDatabase()
				await MainActor.run {
					completion(nil)
				}
			} catch {
				await MainActor.run {
					completion(error)
				}
			}
		}
	}
	
	static func checkPasswordForCertificate(
		for key: URL,
		with password: String,
		using provision: URL
	) -> Bool {
		defer {
			password_check_fix_free(provision.path)
		}
		
		password_check_fix(provision.path)
		
		if (!p12_password_check(key.path, password)) {
			return false
		}
		
		return true
	}
	
	static func movePairing(_ url: URL) {
		let fileManager = FileManager.default
		let dest = URL.documentsDirectory.appendingPathComponent("pairingFile.plist")
		
		try? fileManager.removeFileIfNeeded(at: dest)
		
		try? fileManager.copyItem(at: url, to: dest)
		
		HeartbeatManager.shared.start(true)
	}
	
	static func downloadSSLCertificates(
		from urlString: String,
		completion: @escaping (Bool) -> Void
	) {
		let generator = UINotificationFeedbackGenerator()
		generator.prepare()
		
		NBFetchService().fetch(from: urlString) { (result: Result<ServerView.ServerPackModel, Error>) in
			switch result {
			case .success(let pack):
				do {
					try FileManager.forceWrite(content: pack.key, to: "server.pem")
					try FileManager.forceWrite(content: pack.cert, to: "server.crt")
					try FileManager.forceWrite(content: pack.info.domains.commonName, to: "commonName.txt")
					generator.notificationOccurred(.success)
					completion(true)
				} catch {
					completion(false)
				}
			case .failure(_):
				completion(false)
			}
		}
	}
	
	static func handleSource(
		_ urlString: String,
		competion: @escaping () -> Void
	) {
		guard let url = URL(string: urlString) else { return }
		
		NBFetchService().fetch<ASRepository>(from: url) { (result: Result<ASRepository, Error>) in
			switch result {
			case .success(let data):
				let id = data.id ?? url.absoluteString
				
				if !Storage.shared.sourceExists(id) {
					Storage.shared.addSource(url, repository: data, id: id) { _ in
						competion()
					}
				} else {
					DispatchQueue.main.async {
						UIAlertController.showAlertWithOk(title: .localized("Error"), message: .localized("Repository already added."))
					}
				}
			case .failure(let error):
				DispatchQueue.main.async {
					UIAlertController.showAlertWithOk(title: .localized("Error"), message: error.localizedDescription)
				}
			}
		}
	}
	
	static func exportCertificateAndOpenUrl(using template: String) {
		// Helper that performs the export for a given certificate
		func performExport(for certificate: CertificatePair) {
			guard
				let certificateKeyFile = Storage.shared.getFile(.certificate, from: certificate),
				let certificateKeyFileData = try? Data(contentsOf: certificateKeyFile)
			else {
				return
			}
			
			let base64encodedCert = certificateKeyFileData.base64EncodedString()
			
			var allowedQueryParamAndKey = NSCharacterSet.urlQueryAllowed
			allowedQueryParamAndKey.remove(charactersIn: ";/?:@&=+$, ")
			
			guard let encodedCert = base64encodedCert.addingPercentEncoding(withAllowedCharacters: allowedQueryParamAndKey) else {
				return
			}
			
			let urlStr = template
				.replacingOccurrences(of: "$(BASE64_CERT)", with: encodedCert)
				.replacingOccurrences(of: "$(PASSWORD)", with: certificate.password ?? "")
			
			guard let callbackUrl = URL(string: urlStr) else {
				return
			}
			
			UIApplication.shared.open(callbackUrl)
		}
		
		let certificates = Storage.shared.getAllCertificates()
		guard !certificates.isEmpty else { return }
		
		DispatchQueue.main.async {
			var selectionActions: [UIAlertAction] = []
			
			for cert in certificates {
				var title: String
				let decoded = Storage.shared.getProvisionFileDecoded(for: cert)
				
				title = cert.nickname ?? decoded?.Name ?? .localized("Unknown")
				
				if let getTaskAllow = decoded?.Entitlements?["get-task-allow"]?.value as? Bool, getTaskAllow == true {
					title = "🐞 \(title)"
				}
				
				let selectAction = UIAlertAction(title: title, style: .default) { _ in
					performExport(for: cert)
				}
				selectionActions.append(selectAction)
			}
			
			UIAlertController.showAlertWithCancel(
				title: .localized("Export Certificate"),
				message: .localized("Do you want to export your certificate to an external app? That app will be able to sign apps using your certificate."),
				style: .alert,
				actions: selectionActions
			)
		}
	}
}

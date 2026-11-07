import Foundation
import Zsign
import UIKit

final class ZsignHandler {
	var hadError: Error?

	private var _appUrl: URL
	private var _options: Options
	private var _certificate: CertificatePair?

	init(
		appUrl: URL,
		options: Options = OptionsManager.shared.options,
		cert: CertificatePair? = nil
	) {
		self._appUrl = appUrl
		self._options = options
		self._certificate = cert
	}

	func disinject() async throws {
		guard !_options.disInjectionFiles.isEmpty else {
			return
		}

		let bundle = Bundle(url: _appUrl)
		let execPath = _appUrl.appendingPathComponent(bundle?.exec ?? "").relativePath

		if !Zsign.removeDylibs(appExecutable: execPath, using: _options.disInjectionFiles) {
			throw SigningFileHandlerError.disinjectFailed
		}
	}

	func sign() async throws {
		guard let cert = _certificate else {
			throw SigningFileHandlerError.missingCertifcate
		}

		let material = await MainActor.run {
			(Storage.shared.getFile(.provision, from: cert)?.path ?? "", Storage.shared.getFile(.certificate, from: cert)?.path ?? "", cert.password ?? "")
		}
		let success = Zsign.sign(
			appPath: _appUrl.relativePath,
			provisionPath: material.0,
			p12Path: material.1,
			p12Password: material.2,
			entitlementsPath: _options.appEntitlementsFile?.path ?? "",
			removeProvision: !_options.removeProvisioning,
			completion: { success in
				if !success {
					self.hadError = SigningFileHandlerError.signFailed
				}
			}
		)
		if !success { throw SigningFileHandlerError.signFailed }
	}

	func adhocSign() async throws {
		let success = Zsign.sign(
			appPath: _appUrl.relativePath,
			entitlementsPath: _options.appEntitlementsFile?.path ?? "",
			adhoc: true,
			removeProvision: !_options.removeProvisioning,
			completion: { success in
				if !success {
					self.hadError = SigningFileHandlerError.signFailed
				}
			}
		)
		if !success { throw SigningFileHandlerError.signFailed }
	}
}

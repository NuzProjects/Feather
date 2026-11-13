import Foundation
import UIKit
import NimbleExtensions

struct AppleIDMarker: Codable {
	let appleID: String
	let teamID: String
	let teamName: String
}

private struct AppleIDRecord: Codable {
	var appleID: String
	var password: String
	var adsid: String?
	var token: String?
	var tokenExpiry: Date?
	var teamID: String
	var teamName: String
	var serialNumber: String
	var udid: String
	var anisette: AnisetteState?
}

enum AppleIDAccountError: LocalizedError {
	case missingAccount
	case certificateGone

	var errorDescription: String? {
		switch self {
		case .missingAccount: .localized("This Apple ID's sign-in details are missing. Delete it and sign in again in Settings → Certificates.")
		case .certificateGone: .localized("The certificate for this Apple ID was revoked, possibly by another signing tool. Delete it and sign in again to make a new one.")
		}
	}
}

enum AppleIDAccount {
	static let markerName = "appleid.json"
	static let appLifetimeDays = 7
	private static let keychainService = "Feather.AppleID"
	private static var _markerCache: [String: AppleIDMarker?] = [:]
	private static let _cacheLock = NSLock()

	static func marker(for cert: CertificatePair) -> AppleIDMarker? {
		guard let uuid = cert.uuid else { return nil }
		_cacheLock.lock()
		defer { _cacheLock.unlock() }
		if let cached = _markerCache[uuid] { return cached }
		let url = FileManager.default.certificates(uuid).appendingPathComponent(markerName)
		let marker = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(AppleIDMarker.self, from: $0) }
		_markerCache[uuid] = marker
		return marker
	}

	static func isAppleID(_ cert: CertificatePair) -> Bool {
		marker(for: cert) != nil
	}

	static func forget(uuid: String) {
		_cacheLock.lock()
		_markerCache[uuid] = nil
		_cacheLock.unlock()
		SecItemDelete([
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: keychainService,
			kSecAttrAccount as String: uuid
		] as CFDictionary)
	}

	enum UDIDSource {
		case pairing
		case profile
	}

	static let detectedUDIDNotification = Notification.Name("Feather.AppleID.detectedUDID")
	static let udidProfileURL = URL(string: "https://feather.madebynuz.dev/udid")!
	private static let detectedUDIDKey = "AppleID.detectedUDID"

	static var knownUDID: (value: String, source: UDIDSource)? {
		if let udid = pairingFileUDID() { return (udid, .pairing) }
		if let udid = UserDefaults.standard.string(forKey: detectedUDIDKey), isValidUDID(udid) { return (udid, .profile) }
		return nil
	}

	static func isValidUDID(_ value: String) -> Bool {
		value.range(of: "^[0-9A-Fa-f-]{24,40}$", options: .regularExpression) != nil
	}

	static func receiveDetectedUDID(_ value: String) {
		let udid = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
		guard isValidUDID(udid) else { return }
		UserDefaults.standard.set(udid, forKey: detectedUDIDKey)
		NotificationCenter.default.post(name: detectedUDIDNotification, object: udid)
	}

	static func pairingFileUDID() -> String? {
		let url = URL.documentsDirectory.appendingPathComponent("pairingFile.plist")
		guard
			let data = try? Data(contentsOf: url),
			let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
			let udid = plist["UDID"] as? String,
			!udid.isEmpty
		else { return nil }
		return udid
	}

	private static func _load(_ uuid: String) -> AppleIDRecord? {
		var result: CFTypeRef?
		let status = SecItemCopyMatching([
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: keychainService,
			kSecAttrAccount as String: uuid,
			kSecReturnData as String: true
		] as CFDictionary, &result)
		guard status == errSecSuccess, let data = result as? Data else { return nil }
		return try? JSONDecoder().decode(AppleIDRecord.self, from: data)
	}

	private static func _save(_ record: AppleIDRecord, uuid: String) {
		guard let data = try? JSONEncoder().encode(record) else { return }
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: keychainService,
			kSecAttrAccount as String: uuid
		]
		let update: [String: Any] = [kSecValueData as String: data]
		if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecItemNotFound {
			var add = query
			add[kSecValueData as String] = data
			add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
			SecItemAdd(add as CFDictionary, nil)
		}
	}

	static func signIn(
		appleID: String,
		password: String,
		udid: String,
		code: @escaping VerificationCodeProvider,
		confirmRevoke: @escaping (Int) async -> Bool
	) async throws {
		let uuid = UUID().uuidString
		var anisetteState: AnisetteState?
		let anisette = AnisetteProvider(state: nil) { anisetteState = $0 }
		let lookup = GrandSlamLookup(anisette: anisette)
		let client = GrandSlamClient(lookup: lookup)

		let appleID = appleID.lowercased()
		let login = try await client.authenticate(username: appleID, password: password, code: code)
		let token = try await client.xcodeToken(for: login)
		let services = DeveloperServices(lookup: lookup, adsid: login.adsid, token: token.token)

		guard let team = try await services.teams().first else { throw DeveloperServicesError.noTeam }
		services.teamID = team.id

		let deviceName = await MainActor.run { UIDevice.current.name }
		try await services.registerDevice(udid: udid, name: deviceName)

		let keys = try SigningKeyPair()
		let request = try keys.certificateRequest(commonName: "Feather")
		let certificate: Data
		do {
			certificate = try await services.createCertificate(csr: request)
		} catch {
			let existing = try await services.certificates()
			guard !existing.isEmpty else { throw error }
			guard await confirmRevoke(existing.count) else { throw GrandSlamError.cancelled }
			for item in existing {
				try await services.revokeCertificate(id: item.id)
			}
			certificate = try await services.createCertificate(csr: request)
		}

		let p12Password = UUID().uuidString
		let p12 = try keys.pkcs12(certificate: certificate, password: p12Password, name: "Feather (\(appleID))")
		guard let serial = SigningCertificateInfo.serialNumber(of: certificate) else { throw AppleIDCryptoError.failed("serial") }
		let expiration = SigningCertificateInfo.expiration(of: certificate) ?? Date().addingTimeInterval(365 * 86400)

		let directory = FileManager.default.certificates(uuid)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		try p12.write(to: directory.appendingPathComponent("AppleID.p12"), options: .atomic)
		try JSONEncoder().encode(AppleIDMarker(appleID: appleID, teamID: team.id, teamName: team.name))
			.write(to: directory.appendingPathComponent(markerName), options: .atomic)

		_save(AppleIDRecord(
			appleID: appleID,
			password: password,
			adsid: login.adsid,
			token: token.token,
			tokenExpiry: token.expiry,
			teamID: team.id,
			teamName: team.name,
			serialNumber: serial,
			udid: udid,
			anisette: anisetteState ?? anisette.state
		), uuid: uuid)

		await MainActor.run {
			Storage.shared.addCertificate(uuid: uuid, password: p12Password, expiration: expiration) { _ in }
		}
	}

	struct Provisioned {
		let bundleIdentifier: String
		let profile: Data
	}

	static func provision(_ cert: CertificatePair, bundleIdentifier original: String) async throws -> Provisioned {
		guard let uuid = cert.uuid, var record = _load(uuid) else { throw AppleIDAccountError.missingAccount }

		let anisette = AnisetteProvider(state: record.anisette) { state in
			record.anisette = state
			_save(record, uuid: uuid)
		}
		let lookup = GrandSlamLookup(anisette: anisette)

		let services: DeveloperServices
		if let adsid = record.adsid, let token = record.token, let expiry = record.tokenExpiry, expiry > Date().addingTimeInterval(300) {
			services = DeveloperServices(lookup: lookup, adsid: adsid, token: token, teamID: record.teamID)
		} else {
			let client = GrandSlamClient(lookup: lookup)
			let login = try await client.authenticate(username: record.appleID, password: record.password) { bySMS in
				await AppleIDCodePrompt.ask(appleID: record.appleID, bySMS: bySMS)
			}
			let token = try await client.xcodeToken(for: login)
			record.adsid = login.adsid
			record.token = token.token
			record.tokenExpiry = token.expiry
			record.anisette = anisette.state
			_save(record, uuid: uuid)
			services = DeveloperServices(lookup: lookup, adsid: login.adsid, token: token.token, teamID: record.teamID)
		}

		let suffix = "." + record.teamID
		let identifier = original.hasSuffix(suffix) ? original : original + suffix
		let name = "Feather " + identifier.map { $0.isLetter || $0.isNumber ? String($0) : " " }.joined()

		let deviceName = await MainActor.run { UIDevice.current.name }
		try? await services.registerDevice(udid: record.udid, name: deviceName)
		let bundleID = try await services.bundleID(identifier, name: String(name.prefix(60)))
		guard let certificate = try await services.certificates().first(where: { $0.serialNumber == record.serialNumber }) else {
			await MainActor.run {
				cert.revoked = true
				Storage.shared.saveContext()
			}
			throw AppleIDAccountError.certificateGone
		}
		let devices = try await services.deviceIDs()
		let profile = try await services.profile(bundleID: bundleID, certificateID: certificate.id, deviceIDs: devices)
		return Provisioned(bundleIdentifier: identifier, profile: profile)
	}
}

enum AppleIDCodePrompt {
	@MainActor
	static func ask(appleID: String, bySMS: Bool) async -> String? {
		await withCheckedContinuation { continuation in
			let alert = UIAlertController(
				title: .localized("Verification Code"),
				message: bySMS
					? String(format: .localized("Enter the code Apple texted to the phone number for %@."), appleID)
					: String(format: .localized("Enter the code shown on your other Apple devices for %@."), appleID),
				preferredStyle: .alert
			)
			alert.addTextField {
				$0.keyboardType = .numberPad
				$0.textContentType = .oneTimeCode
				$0.placeholder = "123456"
			}
			alert.addAction(UIAlertAction(title: .localized("Cancel"), style: .cancel) { _ in
				continuation.resume(returning: nil)
			})
			alert.addAction(UIAlertAction(title: .localized("Continue"), style: .default) { _ in
				let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
				continuation.resume(returning: text.isEmpty ? nil : text)
			})
			guard let presenter = UIApplication.topViewController() else {
				continuation.resume(returning: nil)
				return
			}
			presenter.present(alert, animated: true)
		}
	}
}

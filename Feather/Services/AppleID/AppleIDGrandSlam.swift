import Foundation

enum GrandSlamError: LocalizedError {
	case apple(code: Int, message: String)
	case badResponse(String)
	case wrongCode
	case cancelled
	case twoFactorFailed

	var errorDescription: String? {
		switch self {
		case .apple(let code, let message):
			if code == -22406 { return .localized("The Apple ID or password is incorrect.") }
			return "\(message) (\(code))"
		case .badResponse(let step): String(format: .localized("Apple sent an unexpected reply (%@). Try again."), step)
		case .wrongCode: .localized("That verification code is incorrect.")
		case .cancelled: .localized("Sign-in was cancelled.")
		case .twoFactorFailed: .localized("Two-factor verification didn't complete. Try signing in again.")
		}
	}
}

struct GrandSlamLogin {
	let adsid: String
	let idmsToken: String
	let sessionKey: Data
	let cookie: Data

	var identityToken: String {
		Data("\(adsid):\(idmsToken)".utf8).base64EncodedString()
	}
}

typealias VerificationCodeProvider = (_ sentBySMS: Bool) async -> String?

final class GrandSlamLookup {
	static let xcodeVersion = "26.5 (17F42)"
	private static let lookupURL = URL(string: "https://gsa.apple.com/grandslam/GsService2/lookup")!

	let anisette: AnisetteProvider
	private var _endpoints: [String: String]?

	init(anisette: AnisetteProvider) {
		self.anisette = anisette
	}

	static func session() -> URLSession {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.httpShouldUsePipelining = false
		configuration.httpMaximumConnectionsPerHost = 1
		return URLSession(configuration: configuration)
	}

	func endpoint(_ key: String) async throws -> URL {
		if _endpoints == nil {
			let info = try await anisette.clientInfo()
			var request = URLRequest(url: Self.lookupURL)
			request.setValue(info.userAgent, forHTTPHeaderField: "User-Agent")
			request.setValue(Locale.current.identifier, forHTTPHeaderField: "X-Apple-I-Locale")
			request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "X-Apple-I-TimeZone")
			request.setValue(info.clientInfo, forHTTPHeaderField: "X-MMe-Client-Info")
			request.setValue(anisette.deviceID, forHTTPHeaderField: "X-Mme-Device-Id")
			let session = Self.session()
			defer { session.finishTasksAndInvalidate() }
			let (data, _) = try await session.data(for: request)
			guard
				let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
				let urls = plist["urls"] as? [String: String]
			else { throw GrandSlamError.badResponse("lookup") }
			_endpoints = urls
		}
		guard let value = _endpoints?[key], let url = URL(string: value) else { throw GrandSlamError.badResponse("lookup") }
		return url
	}

	func provisioningRequest(endpoint key: String, body: [String: Any], headers: [String: String]) async throws -> [String: Any] {
		var request = URLRequest(url: try await endpoint(key))
		request.httpMethod = "POST"
		request.setValue("text/x-xml-plist", forHTTPHeaderField: "Content-Type")
		request.setValue("en_US", forHTTPHeaderField: "Accept-Language")
		if let region = Locale.current.regionCode { request.setValue(region, forHTTPHeaderField: "X-MMe-Country") }
		headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
		request.httpBody = try PropertyListSerialization.data(fromPropertyList: ["Header": [String: Any](), "Request": body], format: .xml, options: 0)
		let session = Self.session()
		defer { session.finishTasksAndInvalidate() }
		let (data, _) = try await session.data(for: request)
		return try Self.operationResponse(data)
	}

	static func operationResponse(_ data: Data) throws -> [String: Any] {
		guard
			let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
			let response = plist["Response"] as? [String: Any]
		else { throw GrandSlamError.badResponse("response") }
		if let status = response["Status"] as? [String: Any], let code = (status["ec"] as? NSNumber)?.intValue, code != 0 {
			throw GrandSlamError.apple(code: code, message: (status["em"] as? String) ?? "")
		}
		return response
	}
}

final class GrandSlamClient {
	private let _lookup: GrandSlamLookup

	init(lookup: GrandSlamLookup) {
		self._lookup = lookup
	}

	private func _operation(_ name: String, username: String, parameters: [String: Any]) async throws -> [String: Any] {
		let headers = try await _lookup.anisette.headers(lookup: _lookup)
		var clientData: [String: Any] = [
			"bootstrap": true,
			"icscrec": true,
			"pbe": false,
			"prkgen": true,
			"svct": "iCloud",
			"loc": Locale.current.identifier
		]
		headers.dictionary.forEach { clientData[$0] = $1 }

		var body: [String: Any] = ["o": name, "u": username, "cpd": clientData]
		parameters.forEach { body[$0] = $1 }

		var request = URLRequest(url: try await _lookup.endpoint("gsService"))
		request.httpMethod = "POST"
		request.setValue("text/x-xml-plist", forHTTPHeaderField: "Content-Type")
		request.setValue("*/*", forHTTPHeaderField: "Accept")
		request.setValue(headers.userAgent, forHTTPHeaderField: "User-Agent")
		request.setValue(headers.clientInfo, forHTTPHeaderField: "X-MMe-Client-Info")
		request.httpBody = try PropertyListSerialization.data(
			fromPropertyList: ["Header": ["Version": "1.0.1"], "Request": body],
			format: .xml,
			options: 0
		)
		let session = GrandSlamLookup.session()
		defer { session.finishTasksAndInvalidate() }
		let (data, _) = try await session.data(for: request)
		return try GrandSlamLookup.operationResponse(data)
	}

	func authenticate(username: String, password: String, code: VerificationCodeProvider) async throws -> GrandSlamLogin {
		try await _authenticate(username: username, password: password, code: code, isRetry: false)
	}

	private func _authenticate(username: String, password: String, code: VerificationCodeProvider, isRetry: Bool) async throws -> GrandSlamLogin {
		var srp = SRPClient()
		let protocols = ["s2k", "s2k_fo"]
		let start = try await _operation("init", username: username, parameters: ["ps": protocols, "A2k": srp.publicKey])
		guard
			let selected = start["sp"] as? String,
			let cookie = start["c"] as? String,
			let salt = start["s"] as? Data,
			let iterations = (start["i"] as? NSNumber)?.intValue,
			let serverKey = start["B"] as? Data
		else { throw GrandSlamError.badResponse("init") }

		let proof = try srp.clientProof(
			username: username,
			password: password,
			salt: salt,
			iterations: iterations,
			legacy: selected == "s2k_fo",
			serverPublicKey: serverKey
		)
		let complete = try await _operation("complete", username: username, parameters: ["c": cookie, "M1": proof])
		guard
			let serverProof = complete["M2"] as? Data,
			serverProof == srp.expectedServerProof,
			let encrypted = complete["spd"] as? Data
		else { throw GrandSlamError.badResponse("complete") }

		let decrypted = try srp.decrypt(encrypted)
		guard
			let spd = try PropertyListSerialization.propertyList(from: decrypted, format: nil) as? [String: Any],
			let adsid = spd["adsid"] as? String,
			let idmsToken = spd["GsIdmsToken"] as? String,
			let sessionKey = spd["sk"] as? Data,
			let loginCookie = spd["c"] as? Data
		else { throw GrandSlamError.badResponse("session") }
		let login = GrandSlamLogin(adsid: adsid, idmsToken: idmsToken, sessionKey: sessionKey, cookie: loginCookie)

		let status = complete["Status"] as? [String: Any]
		let mode = (status?["au"] as? String) ?? (spd["url"] as? String)
		let needsSecondFactor = mode == "trustedDeviceSecondaryAuth" || mode == "secondaryAuth" || (spd["status-code"] as? NSNumber)?.intValue == 409
		guard needsSecondFactor else { return login }
		guard !isRetry else { throw GrandSlamError.twoFactorFailed }

		try await _secondFactor(mode: mode, login: login, code: code)
		return try await _authenticate(username: username, password: password, code: code, isRetry: true)
	}

	private func _secondFactorRequest(_ url: URL, login: GrandSlamLogin, method: String = "GET", json: [String: Any]? = nil, extra: [String: String] = [:]) async throws -> (Int, Data) {
		let headers = try await _lookup.anisette.headers(lookup: _lookup)
		var request = URLRequest(url: url)
		request.httpMethod = method
		request.setValue("application/x-buddyml", forHTTPHeaderField: "Accept")
		request.setValue("application/x-plist", forHTTPHeaderField: "Content-Type")
		request.setValue(headers.userAgent, forHTTPHeaderField: "User-Agent")
		request.setValue("com.apple.gs.xcode.auth", forHTTPHeaderField: "X-Apple-App-Info")
		request.setValue(GrandSlamLookup.xcodeVersion, forHTTPHeaderField: "X-Xcode-Version")
		request.setValue(login.identityToken, forHTTPHeaderField: "X-Apple-Identity-Token")
		headers.dictionary.forEach { request.setValue($1, forHTTPHeaderField: $0) }
		if let json {
			request.setValue("application/json", forHTTPHeaderField: "Content-Type")
			request.setValue("application/json", forHTTPHeaderField: "Accept")
			request.httpBody = try JSONSerialization.data(withJSONObject: json)
		}
		extra.forEach { request.setValue($1, forHTTPHeaderField: $0) }
		let session = GrandSlamLookup.session()
		defer { session.finishTasksAndInvalidate() }
		let (data, response) = try await session.data(for: request)
		return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
	}

	private func _secondFactor(mode: String?, login: GrandSlamLogin, code: VerificationCodeProvider) async throws {
		if mode == "secondaryAuth" {
			let phone = ["id": 1]
			let (status, _) = try await _secondFactorRequest(
				URL(string: "https://gsa.apple.com/auth/verify/phone")!,
				login: login,
				method: "PUT",
				json: ["phoneNumber": phone, "mode": "sms"]
			)
			if (200..<300).contains(status) {
				guard let entered = await code(true) else { throw GrandSlamError.cancelled }
				let (verifyStatus, _) = try await _secondFactorRequest(
					URL(string: "https://gsa.apple.com/auth/verify/phone/securitycode")!,
					login: login,
					method: "POST",
					json: ["securityCode": ["code": entered], "phoneNumber": phone, "mode": "sms"]
				)
				guard (200..<300).contains(verifyStatus) else { throw GrandSlamError.wrongCode }
				return
			}
		}

		_ = try? await _secondFactorRequest(try await _lookup.endpoint("trustedDeviceSecondaryAuth"), login: login)
		guard let entered = await code(false) else { throw GrandSlamError.cancelled }
		let (_, data) = try await _secondFactorRequest(
			try await _lookup.endpoint("validateCode"),
			login: login,
			extra: ["security-code": entered]
		)
		if
			let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
			let errorCode = (plist["ec"] as? NSNumber)?.intValue, errorCode != 0
		{
			throw GrandSlamError.wrongCode
		}
	}

	func xcodeToken(for login: GrandSlamLogin) async throws -> (token: String, expiry: Date) {
		let app = "com.apple.gs.xcode.auth"
		let checksum = AppleIDCrypto.hmac(key: login.sessionKey, Data("apptokens".utf8) + Data(login.adsid.utf8) + Data(app.utf8))
		let response = try await _operation("apptokens", username: login.adsid, parameters: [
			"app": [app],
			"c": login.cookie,
			"t": login.idmsToken,
			"checksum": checksum
		])
		guard let encrypted = response["et"] as? Data else { throw GrandSlamError.badResponse("token") }
		let decrypted = try AppleIDCrypto.decryptGCM(encrypted, key: login.sessionKey)
		guard
			let plist = try PropertyListSerialization.propertyList(from: decrypted, format: nil) as? [String: Any],
			let tokens = plist["t"] as? [String: Any],
			let entry = tokens[app] as? [String: Any],
			let token = entry["token"] as? String
		else { throw GrandSlamError.badResponse("token") }
		let expiry = (entry["expiry"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) } ?? Date().addingTimeInterval(3600 * 12)
		return (token, expiry)
	}
}

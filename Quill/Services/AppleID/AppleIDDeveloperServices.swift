import Foundation

enum DeveloperServicesError: LocalizedError {
	case apple(String)
	case badResponse(String)
	case noTeam

	var errorDescription: String? {
		switch self {
		case .apple(let message): message
		case .badResponse(let step): String(format: .localized("Apple's developer service sent an unexpected reply (%@). Try again."), step)
		case .noTeam: .localized("This Apple ID isn't set up for app signing yet. Sign in once at developer.apple.com, accept the agreement, then try again.")
		}
	}
}

struct DeveloperTeam {
	let id: String
	let name: String
}

struct DeveloperCertificate {
	let id: String
	let serialNumber: String
	let name: String
}

final class DeveloperServices {
	private static let base = "https://developerservices2.apple.com/services/"

	private let _lookup: GrandSlamLookup
	private let _adsid: String
	private let _token: String
	var teamID: String?

	init(lookup: GrandSlamLookup, adsid: String, token: String, teamID: String? = nil) {
		self._lookup = lookup
		self._adsid = adsid
		self._token = token
		self.teamID = teamID
	}

	private func _baseRequest(_ url: URL, accept: String) async throws -> URLRequest {
		let anisette = try await _lookup.anisette.headers(lookup: _lookup)
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue(Locale.preferredLanguages.joined(separator: ", "), forHTTPHeaderField: "Accept-Language")
		request.setValue(accept, forHTTPHeaderField: "Accept")
		request.setValue(accept, forHTTPHeaderField: "Content-Type")
		request.setValue("Xcode", forHTTPHeaderField: "User-Agent")
		request.setValue(GrandSlamLookup.xcodeVersion, forHTTPHeaderField: "X-Xcode-Version")
		request.setValue(_adsid, forHTTPHeaderField: "X-Apple-I-Identity-Id")
		request.setValue("com.apple.gs.xcode.auth", forHTTPHeaderField: "X-Apple-App-Info")
		request.setValue(_token, forHTTPHeaderField: "X-Apple-GS-Token")
		anisette.dictionary.forEach { request.setValue($1, forHTTPHeaderField: $0) }
		return request
	}

	func teams() async throws -> [DeveloperTeam] {
		let url = URL(string: Self.base + "QH65B2/listTeams.action?clientId=XABBG36SBA")!
		var request = try await _baseRequest(url, accept: "text/x-xml-plist")
		request.httpBody = try PropertyListSerialization.data(fromPropertyList: [
			"requestId": UUID().uuidString,
			"clientId": "XABBG36SBA",
			"protocolVersion": "QH65B2",
			"userLocale": [Locale.current.identifier]
		], format: .xml, options: 0)
		let data = try await GrandSlamLookup.send(request, step: "teams")
		let plist = try GrandSlamLookup.plist(data, step: "teams")
		let resultCode = (plist["resultCode"] as? NSNumber)?.intValue ?? Int((plist["resultCode"] as? String) ?? "") ?? 0
		guard resultCode == 0 else {
			throw DeveloperServicesError.apple((plist["userString"] as? String) ?? (plist["resultString"] as? String) ?? "Error \(resultCode)")
		}
		let teams = (plist["teams"] as? [[String: Any]]) ?? []
		return teams.compactMap { team in
			guard let id = team["teamId"] as? String else { return nil }
			return DeveloperTeam(id: id, name: (team["name"] as? String) ?? id)
		}
	}

	@discardableResult
	private func _api(_ method: String, _ path: String, query: [(String, String)] = [], body: [String: Any]? = nil, allowed: Set<Int> = []) async throws -> (Int, [String: Any]) {
		guard let teamID else { throw DeveloperServicesError.noTeam }
		var request = try await _baseRequest(URL(string: Self.base + "v1/" + path)!, accept: "application/vnd.api+json")
		if method == "GET" || method == "DELETE" {
			request.setValue(method, forHTTPHeaderField: "X-HTTP-Method-Override")
			var allowedCharacters = CharacterSet.alphanumerics
			allowedCharacters.insert(charactersIn: "-._~")
			let encoded = (query + [("teamId", teamID)]).map { key, value in
				"\(key.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? key)=\(value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? value)"
			}.joined(separator: "&")
			request.httpBody = try JSONSerialization.data(withJSONObject: ["urlEncodedQueryParams": encoded])
		} else {
			var payload = body ?? [:]
			var data = (payload["data"] as? [String: Any]) ?? [:]
			var attributes = (data["attributes"] as? [String: Any]) ?? [:]
			attributes["teamId"] = teamID
			data["attributes"] = attributes
			payload["data"] = data
			request.httpBody = try JSONSerialization.data(withJSONObject: payload)
		}
		let (data, response) = try await URLSession.shared.data(for: request)
		let status = (response as? HTTPURLResponse)?.statusCode ?? 0
		let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
		if (200..<300).contains(status) || allowed.contains(status) {
			return (status, json)
		}
		let firstError = (json["errors"] as? [[String: Any]])?.first
		let message = (firstError?["detail"] as? String) ?? (firstError?["title"] as? String) ?? HTTPURLResponse.localizedString(forStatusCode: status)
		throw DeveloperServicesError.apple(message)
	}

	private static func _items(_ json: [String: Any]) -> [[String: Any]] {
		(json["data"] as? [[String: Any]]) ?? []
	}

	func registerDevice(udid: String, name: String) async throws {
		try await _api("POST", "devices", body: ["data": [
			"type": "devices",
			"attributes": ["name": name, "udid": udid, "platform": "IOS"]
		]], allowed: [409])
	}

	func deviceIDs() async throws -> [String] {
		let (_, json) = try await _api("GET", "devices", query: [("limit", "200")])
		return Self._items(json).compactMap { item in
			let attributes = item["attributes"] as? [String: Any]
			if (attributes?["status"] as? String) == "DISABLED" { return nil }
			if let deviceClass = attributes?["deviceClass"] as? String, !["IPHONE", "IPAD", "IPOD"].contains(deviceClass) { return nil }
			return item["id"] as? String
		}
	}

	func certificates() async throws -> [DeveloperCertificate] {
		let (_, json) = try await _api("GET", "certificates", query: [("limit", "200")])
		return Self._items(json).compactMap { item in
			guard let id = item["id"] as? String else { return nil }
			let attributes = item["attributes"] as? [String: Any]
			let serial = (attributes?["serialNumber"] as? String).map(SigningCertificateInfo.normalizedSerial) ?? ""
			let name = (attributes?["displayName"] as? String) ?? (attributes?["name"] as? String) ?? ""
			return DeveloperCertificate(id: id, serialNumber: serial, name: name)
		}
	}

	func createCertificate(csr: String) async throws -> Data {
		let (_, json) = try await _api("POST", "certificates", body: ["data": [
			"type": "certificates",
			"attributes": ["csrContent": csr, "certificateType": "DEVELOPMENT"]
		]])
		guard
			let data = json["data"] as? [String: Any],
			let attributes = data["attributes"] as? [String: Any],
			let content = attributes["certificateContent"] as? String,
			let decoded = Data(base64Encoded: content)
		else { throw DeveloperServicesError.badResponse("certificate") }
		return decoded
	}

	func revokeCertificate(id: String) async throws {
		try await _api("DELETE", "certificates/\(id)")
	}

	func bundleID(_ identifier: String, name: String) async throws -> String {
		let (_, json) = try await _api("GET", "bundleIds", query: [("filter[identifier]", identifier), ("limit", "200")])
		if let existing = Self._items(json).first(where: { (($0["attributes"] as? [String: Any])?["identifier"] as? String) == identifier }),
		   let id = existing["id"] as? String {
			return id
		}
		let (_, created) = try await _api("POST", "bundleIds", body: ["data": [
			"type": "bundleIds",
			"attributes": ["name": name, "identifier": identifier, "platform": "IOS"]
		]])
		guard let data = created["data"] as? [String: Any], let id = data["id"] as? String else {
			throw DeveloperServicesError.badResponse("app id")
		}
		return id
	}

	func profile(bundleID: String, certificateID: String, deviceIDs: [String]) async throws -> Data {
		let name = "Feather \(bundleID)"
		let (_, existing) = try await _api("GET", "profiles", query: [("filter[name]", name), ("limit", "200")])
		for item in Self._items(existing) where (item["attributes"] as? [String: Any])?["name"] as? String == name {
			if let id = item["id"] as? String {
				_ = try? await _api("DELETE", "profiles/\(id)")
			}
		}
		let (_, json) = try await _api("POST", "profiles", body: ["data": [
			"type": "profiles",
			"attributes": ["name": name, "profileType": "IOS_APP_DEVELOPMENT"],
			"relationships": [
				"bundleId": ["data": ["type": "bundleIds", "id": bundleID]],
				"certificates": ["data": [["type": "certificates", "id": certificateID]]],
				"devices": ["data": deviceIDs.map { ["type": "devices", "id": $0] }]
			]
		]])
		guard
			let data = json["data"] as? [String: Any],
			let attributes = data["attributes"] as? [String: Any],
			let content = attributes["profileContent"] as? String,
			let decoded = Data(base64Encoded: content)
		else { throw DeveloperServicesError.badResponse("profile") }
		return decoded
	}
}

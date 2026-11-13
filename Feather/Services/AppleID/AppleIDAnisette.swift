import Foundation
import CryptoKit

struct AnisetteHeaders {
	let clientInfo: String
	let userAgent: String
	let deviceID: String
	let localUserID: String
	let machineID: String
	let oneTimePassword: String
	let routingInfo: String

	var dictionary: [String: String] {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.timeZone = TimeZone(identifier: "UTC")
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
		let locale: String = {
			if let language = Locale.current.languageCode, let region = Locale.current.regionCode {
				return "\(language)_\(region)"
			}
			return "en_US"
		}()
		return [
			"X-Apple-Locale": locale,
			"X-Apple-I-TimeZone": TimeZone.current.abbreviation() ?? "UTC",
			"X-Apple-I-Client-Time": formatter.string(from: Date()),
			"X-Apple-I-MD-RINFO": routingInfo,
			"X-Apple-I-MD-M": machineID,
			"X-Apple-I-MD-LU": localUserID,
			"X-Apple-I-MD": oneTimePassword,
			"X-MMe-Client-Info": clientInfo,
			"X-Mme-Device-Id": deviceID
		]
	}
}

struct AnisetteState: Codable {
	var localUserUID: String
	var server: String?
	var provisioning: Data?
	var routingInfo: String?
	var clientInfo: String?
	var userAgent: String?
}

enum AnisetteError: LocalizedError {
	case unreachable
	case provisioningFailed(String)

	var errorDescription: String? {
		switch self {
		case .unreachable: .localized("Feather couldn't reach a sign-in helper server. Check your connection and try again.")
		case .provisioningFailed(let step): String(format: .localized("Setting up this device with Apple failed (%@). Try again in a moment."), step)
		}
	}
}

final class AnisetteProvider {
	static let servers = [
		"https://ani.sidestore.io",
		"https://ani.sidestore.app",
		"https://mac-ani.jkcoxson.com",
		"https://ani.sidestore.zip"
	]

	private(set) var state: AnisetteState
	private let _onChange: (AnisetteState) -> Void

	init(state: AnisetteState?, onChange: @escaping (AnisetteState) -> Void) {
		self.state = state ?? AnisetteState(localUserUID: UUID().uuidString)
		self._onChange = onChange
	}

	var deviceID: String { state.localUserUID }

	var localUserID: String {
		SHA256.hash(data: Data(state.localUserUID.utf8)).map { String(format: "%02X", $0) }.joined()
	}

	private var _identifier: Data {
		guard let uuid = UUID(uuidString: state.localUserUID) else { return Data(count: 16) }
		return withUnsafeBytes(of: uuid.uuid) { Data($0) }
	}

	func clientInfo() async throws -> (clientInfo: String, userAgent: String) {
		if let clientInfo = state.clientInfo, let userAgent = state.userAgent, state.server != nil {
			return (clientInfo, userAgent)
		}
		for server in _orderedServers {
			guard
				let url = URL(string: server + "/v3/client_info"),
				let (data, response) = try? await URLSession.shared.data(from: url),
				(response as? HTTPURLResponse)?.statusCode == 200,
				let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
				let clientInfo = json["client_info"] as? String,
				let userAgent = json["user_agent"] as? String
			else { continue }
			if state.server != server {
				state.provisioning = nil
				state.routingInfo = nil
			}
			state.server = server
			state.clientInfo = clientInfo
			state.userAgent = userAgent
			_onChange(state)
			return (clientInfo, userAgent)
		}
		throw AnisetteError.unreachable
	}

	private var _orderedServers: [String] {
		guard let current = state.server else { return Self.servers }
		return [current] + Self.servers.filter { $0 != current }
	}

	func headers(lookup: GrandSlamLookup) async throws -> AnisetteHeaders {
		let info = try await clientInfo()
		if state.provisioning == nil {
			try await _provision(lookup: lookup, info: info)
		}
		do {
			return try await _fetchHeaders(info: info)
		} catch {
			state.provisioning = nil
			state.routingInfo = nil
			_onChange(state)
			try await _provision(lookup: lookup, info: info)
			return try await _fetchHeaders(info: info)
		}
	}

	private func _fetchHeaders(info: (clientInfo: String, userAgent: String)) async throws -> AnisetteHeaders {
		guard let server = state.server, let provisioning = state.provisioning, let url = URL(string: server + "/v3/get_headers") else {
			throw AnisetteError.provisioningFailed("headers")
		}
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONSerialization.data(withJSONObject: [
			"identifier": _identifier.base64EncodedString(),
			"adi_pb": provisioning.base64EncodedString()
		])
		let (data, _) = try await URLSession.shared.data(for: request)
		guard
			let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
			let machineID = json["X-Apple-I-MD-M"] as? String,
			let otp = json["X-Apple-I-MD"] as? String
		else { throw AnisetteError.provisioningFailed("headers") }
		let routingInfo = (json["X-Apple-I-MD-RINFO"] as? String) ?? (json["X-Apple-I-MD-RINFO"] as? NSNumber)?.stringValue ?? state.routingInfo ?? "17106176"
		if routingInfo != state.routingInfo {
			state.routingInfo = routingInfo
			_onChange(state)
		}
		return AnisetteHeaders(
			clientInfo: info.clientInfo,
			userAgent: info.userAgent,
			deviceID: state.localUserUID,
			localUserID: localUserID,
			machineID: machineID,
			oneTimePassword: otp,
			routingInfo: routingInfo
		)
	}

	private func _provision(lookup: GrandSlamLookup, info: (clientInfo: String, userAgent: String)) async throws {
		guard let server = state.server, var components = URLComponents(string: server + "/v3/provisioning_session") else {
			throw AnisetteError.unreachable
		}
		components.scheme = components.scheme == "http" ? "ws" : "wss"
		guard let socketURL = components.url else { throw AnisetteError.unreachable }

		let deviceHeaders = [
			"X-MMe-Client-Info": info.clientInfo,
			"X-Mme-Device-Id": state.localUserUID,
			"X-Apple-I-MD-LU": localUserID
		]
		let start = try await lookup.provisioningRequest(endpoint: "midStartProvisioning", body: [:], headers: deviceHeaders)
		guard let spim = start["spim"] as? String else { throw AnisetteError.provisioningFailed("start") }

		let socket = URLSession.shared.webSocketTask(with: socketURL)
		socket.resume()
		defer { socket.cancel(with: .normalClosure, reason: nil) }

		_ = try await _receive(socket, expecting: "GiveIdentifier")
		try await _send(socket, ["identifier": _identifier.base64EncodedString()])
		_ = try await _receive(socket, expecting: "GiveStartProvisioningData")
		try await _send(socket, ["spim": spim])
		let endData = try await _receive(socket, expecting: "GiveEndProvisioningData")
		guard let cpim = endData["cpim"] as? String else { throw AnisetteError.provisioningFailed("cpim") }

		let finish = try await lookup.provisioningRequest(endpoint: "midFinishProvisioning", body: ["cpim": cpim], headers: deviceHeaders)
		guard
			let ptm = finish["ptm"] as? String,
			let tk = finish["tk"] as? String
		else { throw AnisetteError.provisioningFailed("finish") }
		let routingInfo = (finish["X-Apple-I-MD-RINFO"] as? String) ?? (finish["X-Apple-I-MD-RINFO"] as? NSNumber)?.stringValue

		try await _send(socket, ["ptm": ptm, "tk": tk])
		let success = try await _receive(socket, expecting: "ProvisioningSuccess")
		guard let adiString = success["adi_pb"] as? String, let adi = Data(base64Encoded: adiString) else {
			throw AnisetteError.provisioningFailed("adi")
		}
		state.provisioning = adi
		state.routingInfo = routingInfo
		_onChange(state)
	}

	private func _send(_ socket: URLSessionWebSocketTask, _ object: [String: String]) async throws {
		let data = try JSONSerialization.data(withJSONObject: object)
		try await socket.send(.string(String(decoding: data, as: UTF8.self)))
	}

	private func _receive(_ socket: URLSessionWebSocketTask, expecting result: String) async throws -> [String: Any] {
		let message = try await socket.receive()
		let data: Data
		switch message {
		case .data(let raw): data = raw
		case .string(let text): data = Data(text.utf8)
		@unknown default: data = Data()
		}
		guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
			throw AnisetteError.provisioningFailed(result)
		}
		guard json["result"] as? String == result else {
			throw AnisetteError.provisioningFailed((json["result"] as? String) ?? result)
		}
		return json
	}
}

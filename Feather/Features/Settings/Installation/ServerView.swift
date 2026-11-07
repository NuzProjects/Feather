import SwiftUI
import NimbleJSON
import NimbleViews

extension ServerView {
	struct ServerPackModel: Decodable {
		static let url = "https://feather.madebynuz.dev/pack.json"

		func save() throws {
			try FileManager.forceWrite(content: key, to: "server.pem")
			try FileManager.forceWrite(content: cert, to: "server.crt")
			try FileManager.forceWrite(content: info.domains.commonName, to: "commonName.txt")
		}

		var cert: String
		var ca: String
		var key: String
		var info: ServerPackInfo

		private enum CodingKeys: String, CodingKey {
			case cert, ca, key1, key2, info
		}

		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			cert = try container.decode(String.self, forKey: .cert)
			ca = try container.decode(String.self, forKey: .ca)
			let key1 = try container.decode(String.self, forKey: .key1)
			let key2 = try container.decode(String.self, forKey: .key2)
			key = key1 + key2
			info = try container.decode(ServerPackInfo.self, forKey: .info)
		}

		struct ServerPackInfo: Decodable {
			var issuer: Domains
			var domains: Domains
		}

		struct Domains: Decodable {
			var commonName: String

			private enum CodingKeys: String, CodingKey {
				case commonName = "commonName"
			}
		}
	}
}

struct ServerView: View {
	@AppStorage("Feather.ipFix") private var _ipFix: Bool = false
	@AppStorage("Feather.serverMethod") private var _serverMethod: Int = 1
	private let _serverMethods: [String] = [.localized("Fully Local"), .localized("Semi Local")]

	private let _dataService = NBFetchService()
	private let _serverPackUrl = ServerPackModel.url

	var body: some View {
		Group {
			Section {
				Picker(.localized("Server Type"), systemImage: "server.rack", selection: $_serverMethod) {
					ForEach(_serverMethods.indices, id: \.description) { index in
						Text(_serverMethods[index]).tag(index)
					}
				}
				Toggle(.localized("Only use localhost address"), systemImage: "lifepreserver", isOn: $_ipFix)
					.disabled(_serverMethod != 1)
			}

			Section {
				Button(.localized("Update SSL Certificates"), systemImage: "arrow.down.doc") {
					FR.downloadSSLCertificates(from: _serverPackUrl) { success in
						if success {
							DispatchQueue.main.async {
								UIAlertController.showAlertWithOk(
									title: .localized("SSL Certificates"),
									message: .localized("Certificates updated successfully.")
								)
							}
						} else {
							DispatchQueue.main.async {
								UIAlertController.showAlertWithOk(
									title: .localized("SSL Certificates"),
									message: .localized("Failed to download, check your internet connection and try again.")
								)
							}
						}
					}
				}
			}
		}
	}
}

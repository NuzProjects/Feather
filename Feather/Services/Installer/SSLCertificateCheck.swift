import Foundation
import NimbleJSON
import UIKit

enum SSLCertificateCheck {
	private static let offeredKey = "Feather.renewedSSLOffered"

	static func run() {
		DispatchQueue.global(qos: .utility).async {
			let wasTrusted = ServerInstaller.isCertificateTrusted()
			let current = ServerInstaller.getUrl("server", ext: "crt").flatMap { try? String(contentsOf: $0, encoding: .utf8) }
			NBFetchService().fetch(from: ServerView.ServerPackModel.url) { (result: Result<ServerView.ServerPackModel, Error>) in
				guard case .success(let pack) = result, pack.cert != current, ServerInstaller.isTrusted(pem: pack.cert) else { return }
				guard (try? pack.save()) != nil else { return }
				guard !wasTrusted else { return }
				DispatchQueue.main.async { offerFullyLocal(for: pack.cert) }
			}
		}
	}

	private static func offerFullyLocal(for cert: String) {
		let defaults = UserDefaults.standard
		guard defaults.integer(forKey: "Feather.serverMethod") != 0, defaults.string(forKey: offeredKey) != cert else { return }
		defaults.set(cert, forKey: offeredKey)
		let alert = UIAlertController(
			title: "Fully Local Works Again",
			message: "Feather downloaded a renewed SSL certificate, so Fully Local can install apps again. Switch the Server Type to Fully Local?",
			preferredStyle: .alert
		)
		alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
		alert.addAction(UIAlertAction(title: "Switch", style: .default) { _ in
			defaults.set(0, forKey: "Feather.serverMethod")
		})
		UIApplication.topViewController()?.present(alert, animated: true)
	}
}

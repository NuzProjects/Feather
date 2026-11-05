import Foundation
import NimbleJSON
import UIKit

/// Picks up a renewed backloop.dev certificate so Fully Local can work again.
enum SSLCertificateCheck {
    private static let offeredKey = "Feather.renewedSSLOffered"

    static func run() {
        DispatchQueue.global(qos: .utility).async {
            guard !ServerInstaller.isCertificateTrusted() else { return }
            NBFetchService().fetch(from: "https://backloop.dev/pack.json") { (result: Result<ServerView.ServerPackModel, Error>) in
                guard case .success(let pack) = result, ServerInstaller.isTrusted(pem: pack.cert) else { return }
                do {
                    try FileManager.forceWrite(content: pack.key, to: "server.pem")
                    try FileManager.forceWrite(content: pack.cert, to: "server.crt")
                    try FileManager.forceWrite(content: pack.info.domains.commonName, to: "commonName.txt")
                } catch {
                    return
                }
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
            message: "backloop.dev renewed its SSL certificate and Feather downloaded it. Switch the Server Type to Fully Local?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
        alert.addAction(UIAlertAction(title: "Switch", style: .default) { _ in
            defaults.set(0, forKey: "Feather.serverMethod")
        })
        UIApplication.topViewController()?.present(alert, animated: true)
    }
}

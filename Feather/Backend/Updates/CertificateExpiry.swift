import Foundation
import UserNotifications

@MainActor
enum CertificateExpiry {
    private static let prefix = "certificate-expiry-"
    private static let warningDays = [3, 1]

    static var selected: CertificatePair? {
        Storage.shared.getCertificate(for: UserDefaults.standard.integer(forKey: "feather.selectedCert"))
    }

    static func refresh() {
        let center = UNUserNotificationCenter.current()
        let prefix = prefix
        let warningDays = warningDays
        center.getPendingNotificationRequests { requests in
            let old = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
        }
        guard let certificate = selected, let expiration = certificate.expiration, expiration > Date() else { return }
        let name = certificate.nickname ?? "Your certificate"
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            for days in warningDays {
                guard let fire = Calendar.current.date(byAdding: .day, value: -days, to: expiration), fire > Date() else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Certificate Expiring"
                content.body = "\(name) expires \(days == 1 ? "tomorrow" : "in \(days) days"). Add a new certificate to keep signing apps."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false)
                center.add(UNNotificationRequest(identifier: prefix + "\(days)", content: content, trigger: trigger))
            }
        }
    }
}

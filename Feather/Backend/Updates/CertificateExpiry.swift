import Foundation
import UserNotifications
import WidgetKit

@MainActor
enum CertificateExpiry {
    private static let prefix = "certificate-expiry-"
    private static let warningDays = [3, 1]

    static var selected: CertificatePair? {
        Storage.shared.getCertificate(for: UserDefaults.standard.integer(forKey: "feather.selectedCert"))
    }

    static func daysLeft(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
    }

    static func countdown(_ date: Date) -> String {
        let days = daysLeft(date)
        if date < Date() { return "Expired" }
        if days == 0 { return "Expires today" }
        if days == 1 { return "Expires tomorrow" }
        return "Expires in \(days) days"
    }

    /// Reschedules warnings for the selected certificate and refreshes the widget.
    static func refresh() {
        SharedWidgetData.write()
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

enum SharedWidgetData {
    static let suite = "group.dev.madebynuz.dev.feather"

    @MainActor
    static func write() {
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        let certificate = CertificateExpiry.selected
        defaults.set(certificate?.nickname, forKey: "certificateName")
        defaults.set(certificate?.expiration, forKey: "certificateExpiration")
        let signed = ((try? Storage.shared.context.fetch(Signed.fetchRequest())) ?? [])
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            .prefix(3)
            .compactMap(\.name)
        defaults.set(Array(signed), forKey: "recentApps")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

import SwiftUI
import WidgetKit

struct FeatherEntry: TimelineEntry {
    let date: Date
    let certificateName: String?
    let expiration: Date?
    let recentApps: [String]
    let accent: Color

    static let placeholder = FeatherEntry(date: .now, certificateName: "My Certificate", expiration: .now.addingTimeInterval(86400 * 30), recentApps: ["Delta", "UTM", "iSH"], accent: Color(hex: "#848ef9"))
}

struct FeatherProvider: TimelineProvider {
    func placeholder(in context: Context) -> FeatherEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (FeatherEntry) -> Void) {
        completion(context.isPreview ? .placeholder : entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FeatherEntry>) -> Void) {
        let next = Calendar.current.startOfDay(for: .now.addingTimeInterval(86400))
        completion(Timeline(entries: [entry()], policy: .after(next)))
    }

    /// Reads what Feather saved to the shared keychain item.
    private func entry() -> FeatherEntry {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Feather.Widget",
            kSecAttrAccount as String: "data",
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        let payload: [String: Any]
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let decoded = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            payload = decoded
        } else {
            payload = [:]
        }
        return FeatherEntry(
            date: .now,
            certificateName: payload["certificateName"] as? String,
            expiration: (payload["certificateExpiration"] as? Double).map(Date.init(timeIntervalSince1970:)),
            recentApps: payload["recentApps"] as? [String] ?? [],
            accent: Color(hex: payload["tint"] as? String ?? "#848ef9")
        )
    }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x848ef9
        self.init(red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255)
    }
}

struct FeatherWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FeatherEntry

    private var daysLeft: Int? {
        guard let expiration = entry.expiration else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: entry.date), to: Calendar.current.startOfDay(for: expiration)).day
    }

    private var tint: Color {
        guard let daysLeft else { return entry.accent }
        return daysLeft < 3 ? .red : daysLeft < 7 ? .orange : entry.accent
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            certificate
            if family == .systemMedium {
                Divider()
                recent
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var certificate: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Certificate", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Spacer(minLength: 0)
            if let daysLeft {
                Text(daysLeft < 0 ? "Expired" : "\(daysLeft)")
                    .font(.system(size: daysLeft < 0 ? 26 : 40, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                Text(daysLeft == 1 ? "day left" : daysLeft < 0 ? "Add a new one" : "days left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Open Feather")
                    .font(.headline)
                Text("to show your certificate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let name = entry.certificateName {
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Recently Signed", systemImage: "signature")
                .font(.caption.weight(.semibold))
                .foregroundStyle(entry.accent)
            if entry.recentApps.isEmpty {
                Text("No apps yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.recentApps, id: \.self) { name in
                    Text(name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FeatherWidget", provider: FeatherProvider()) { entry in
            FeatherWidgetView(entry: entry)
        }
        .configurationDisplayName("Feather")
        .description("Your certificate countdown and recently signed apps.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct FeatherWidgetBundle: WidgetBundle {
    var body: some Widget {
        FeatherWidget()
    }
}

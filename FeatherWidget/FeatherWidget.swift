import SwiftUI
import WidgetKit

struct FeatherEntry: TimelineEntry {
    let date: Date
    let certificateName: String?
    let expiration: Date?
    let recentApps: [String]

    static let placeholder = FeatherEntry(date: .now, certificateName: "My Certificate", expiration: .now.addingTimeInterval(86400 * 30), recentApps: ["Delta", "UTM", "iSH"])
}

struct FeatherProvider: TimelineProvider {
    private let suite = "group.dev.madebynuz.dev.feather"

    func placeholder(in context: Context) -> FeatherEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (FeatherEntry) -> Void) {
        completion(context.isPreview ? .placeholder : entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FeatherEntry>) -> Void) {
        let next = Calendar.current.startOfDay(for: .now.addingTimeInterval(86400))
        completion(Timeline(entries: [entry()], policy: .after(next)))
    }

    private func entry() -> FeatherEntry {
        let defaults = UserDefaults(suiteName: suite)
        return FeatherEntry(
            date: .now,
            certificateName: defaults?.string(forKey: "certificateName"),
            expiration: defaults?.object(forKey: "certificateExpiration") as? Date,
            recentApps: defaults?.stringArray(forKey: "recentApps") ?? []
        )
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
        guard let daysLeft else { return .secondary }
        return daysLeft < 3 ? .red : daysLeft < 7 ? .orange : .green
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
                .foregroundStyle(.secondary)
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

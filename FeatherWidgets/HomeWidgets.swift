import SwiftUI
import WidgetKit

struct SnapshotEntry: TimelineEntry {
	let date: Date
	let snapshot: WidgetSnapshot?

	static let preview = SnapshotEntry(
		date: Date(),
		snapshot: WidgetSnapshot(
			tint: "#848ef9",
			certificate: .init(name: "My Certificate", expiration: Date().addingTimeInterval(86400 * 214), revoked: false),
			signedCount: 6,
			importedCount: 3,
			recent: [
				.init(name: "Delta", version: "1.7", date: Date(), icon: nil),
				.init(name: "UTM", version: "4.6", date: Date(), icon: nil),
				.init(name: "iSH", version: "1.3", date: Date(), icon: nil),
				.init(name: "Aidoku", version: "0.6", date: Date(), icon: nil)
			],
			updated: Date()
		)
	)
}

struct SnapshotProvider: TimelineProvider {
	func placeholder(in context: Context) -> SnapshotEntry { .preview }

	func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
		if context.isPreview, WidgetSnapshotStore.read() == nil {
			completion(.preview)
		} else {
			completion(SnapshotEntry(date: Date(), snapshot: WidgetSnapshotStore.read()))
		}
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
		let now = Date()
		let snapshot = WidgetSnapshotStore.read()
		let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86400))
		let entries = [SnapshotEntry(date: now, snapshot: snapshot), SnapshotEntry(date: midnight, snapshot: snapshot)]
		completion(Timeline(entries: entries, policy: .after(min(midnight.addingTimeInterval(60), now.addingTimeInterval(6 * 3600)))))
	}
}

struct CertificateWidget: Widget {
	var body: some WidgetConfiguration {
		StaticConfiguration(kind: "FeatherCertificateWidget", provider: SnapshotProvider()) { entry in
			CertificateWidgetView(entry: entry)
		}
		.configurationDisplayName("Certificate")
		.description("Days left on your certificate and whether it's still valid.")
		.supportedFamilies([.systemSmall, .systemMedium])
	}
}

struct LibraryWidget: Widget {
	var body: some WidgetConfiguration {
		StaticConfiguration(kind: "FeatherLibraryWidget", provider: SnapshotProvider()) { entry in
			LibraryWidgetView(entry: entry)
		}
		.configurationDisplayName("Library")
		.description("Your signed apps and the ones you signed most recently.")
		.supportedFamilies([.systemSmall, .systemMedium])
	}
}

private struct CertificateWidgetView: View {
	@Environment(\.widgetFamily) private var family
	let entry: SnapshotEntry

	private var accent: Color { Color(widgetHex: entry.snapshot?.tint) }
	private var certificate: WidgetSnapshot.Certificate? { entry.snapshot?.certificate }

	private var daysLeft: Int? {
		guard let expiration = certificate?.expiration else { return nil }
		let calendar = Calendar.current
		return calendar.dateComponents([.day], from: calendar.startOfDay(for: entry.date), to: calendar.startOfDay(for: expiration)).day
	}

	private var status: (text: LocalizedStringKey, color: Color) {
		guard let certificate else { return ("No certificate", .secondary) }
		if certificate.revoked { return ("Revoked", .red) }
		guard let daysLeft else { return ("Valid", accent) }
		if daysLeft < 0 { return ("Expired", .red) }
		if daysLeft < 7 { return ("Expiring soon", .orange) }
		return ("Valid", accent)
	}

	private var ringColor: Color {
		guard let certificate else { return accent }
		if certificate.revoked || (daysLeft ?? 1) < 0 { return .red }
		if let daysLeft, daysLeft < 7 { return .orange }
		return accent
	}

	private var ringFraction: Double {
		guard let certificate, !certificate.revoked, let daysLeft, daysLeft > 0 else { return 0 }
		return min(1, Double(daysLeft) / 365)
	}

	var body: some View {
		Group {
			if family == .systemMedium { medium } else { small }
		}
		.widgetBackground(Color(uiColor: .systemBackground))
	}

	private var header: some View {
		Label("Certificate", systemImage: "checkmark.seal.fill")
			.font(.caption.weight(.semibold))
			.foregroundStyle(accent)
			.lineLimit(1)
	}

	private var ring: some View {
		ZStack {
			Circle().stroke(ringColor.opacity(0.16), lineWidth: 9)
			Circle()
				.trim(from: 0, to: max(0.001, ringFraction))
				.stroke(ringColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
				.rotationEffect(.degrees(-90))
			VStack(spacing: -2) {
				if certificate?.revoked == true {
					Image(systemName: "xmark").font(.title2.weight(.bold)).foregroundStyle(.red)
				} else if let daysLeft {
					Text(daysLeft < 0 ? "0" : "\(daysLeft)")
						.font(.system(size: 30, weight: .bold, design: .rounded))
						.minimumScaleFactor(0.6)
						.lineLimit(1)
					Text(daysLeft == 1 ? "day" : "days")
						.font(.caption2.weight(.medium))
						.foregroundStyle(.secondary)
				} else {
					Image(systemName: "plus").font(.title2.weight(.semibold)).foregroundStyle(accent)
				}
			}
			.padding(.horizontal, 8)
		}
	}

	private var small: some View {
		VStack(alignment: .leading, spacing: 8) {
			header
			ring
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			Text(status.text)
				.font(.caption.weight(.semibold))
				.foregroundStyle(status.color)
				.frame(maxWidth: .infinity)
				.lineLimit(1)
		}
	}

	private var medium: some View {
		HStack(spacing: 18) {
			ring
				.frame(width: 104, height: 104)
			VStack(alignment: .leading, spacing: 6) {
				header
				if let certificate {
					Text(certificate.name)
						.font(.headline)
						.lineLimit(2)
					if let expiration = certificate.expiration {
						Text("Expires \(expiration.formatted(date: .abbreviated, time: .omitted))")
							.font(.subheadline)
							.foregroundStyle(.secondary)
							.lineLimit(1)
					}
				} else {
					Text("Add a certificate")
						.font(.headline)
					Text("Open Feather to sign apps")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				Spacer(minLength: 0)
				HStack(spacing: 6) {
					Circle().fill(status.color).frame(width: 7, height: 7)
					Text(status.text)
						.font(.caption.weight(.semibold))
						.foregroundStyle(status.color)
					if let signed = entry.snapshot?.signedCount, signed > 0 {
						Text("· \(signed) signed")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
				.lineLimit(1)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

private struct LibraryWidgetView: View {
	@Environment(\.widgetFamily) private var family
	let entry: SnapshotEntry

	private var accent: Color { Color(widgetHex: entry.snapshot?.tint) }
	private var apps: [WidgetSnapshot.App] { entry.snapshot?.recent ?? [] }

	var body: some View {
		Group {
			if family == .systemMedium { medium } else { small }
		}
		.foregroundStyle(.white)
		.widgetBackground(
			LinearGradient(colors: [accent, accent.widgetDarker], startPoint: .topLeading, endPoint: .bottomTrailing)
		)
	}

	private var header: some View {
		HStack(spacing: 5) {
			Image(systemName: "square.grid.2x2.fill")
			Text("Library")
		}
		.font(.caption.weight(.semibold))
		.opacity(0.9)
	}

	private var small: some View {
		VStack(alignment: .leading, spacing: 2) {
			header
			Spacer(minLength: 0)
			Text("\(entry.snapshot?.signedCount ?? 0)")
				.font(.system(size: 44, weight: .bold, design: .rounded))
				.minimumScaleFactor(0.6)
				.lineLimit(1)
			Text((entry.snapshot?.signedCount ?? 0) == 1 ? "signed app" : "signed apps")
				.font(.caption.weight(.medium))
				.opacity(0.85)
			Spacer(minLength: 6)
			if let latest = apps.first {
				HStack(spacing: 6) {
					AppIconView(app: latest, size: 22)
					Text(latest.name)
						.font(.caption.weight(.semibold))
						.lineLimit(1)
				}
			} else {
				Text("Sign an app to start")
					.font(.caption)
					.opacity(0.85)
					.lineLimit(1)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var medium: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				header
				Spacer()
				Text("\(entry.snapshot?.signedCount ?? 0) signed · \(entry.snapshot?.importedCount ?? 0) imported")
					.font(.caption)
					.opacity(0.85)
					.lineLimit(1)
			}
			if apps.isEmpty {
				Spacer(minLength: 0)
				Text("Recently signed apps show up here.")
					.font(.subheadline.weight(.medium))
					.opacity(0.9)
				Spacer(minLength: 0)
			} else {
				Spacer(minLength: 0)
				HStack(alignment: .top, spacing: 0) {
					ForEach(0..<4, id: \.self) { index in
						VStack(spacing: 6) {
							if index < apps.count {
								AppIconView(app: apps[index], size: 50)
								Text(apps[index].name)
									.font(.caption2.weight(.semibold))
									.lineLimit(1)
							} else {
								RoundedRectangle(cornerRadius: 12, style: .continuous)
									.fill(Color.white.opacity(0.14))
									.frame(width: 50, height: 50)
								Text(" ").font(.caption2)
							}
						}
						.frame(maxWidth: .infinity)
					}
				}
				Spacer(minLength: 0)
			}
		}
	}
}

private struct AppIconView: View {
	let app: WidgetSnapshot.App
	let size: CGFloat

	var body: some View {
		Group {
			if let data = app.icon, let image = UIImage(data: data) {
				Image(uiImage: image).resizable().scaledToFill()
			} else {
				ZStack {
					Color.white.opacity(0.22)
					Text(String(app.name.prefix(1)).uppercased())
						.font(.system(size: size * 0.45, weight: .bold, design: .rounded))
				}
			}
		}
		.frame(width: size, height: size)
		.clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
	}
}

extension View {
	@ViewBuilder
	func widgetBackground<Background: View>(_ background: Background) -> some View {
		if #available(iOS 17.0, *) {
			containerBackground(for: .widget) { background }
		} else {
			padding(16).background(background)
		}
	}
}

extension Color {
	init(widgetHex hex: String?) {
		let cleaned = (hex ?? "").trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
		if cleaned.count == 6, let value = UInt64(cleaned, radix: 16) {
			self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
		} else {
			self.init(red: 0.518, green: 0.557, blue: 0.976)
		}
	}

	var widgetDarker: Color {
		var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
		UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
		return Color(hue: Double(hue), saturation: Double(min(1, saturation * 1.1)), brightness: Double(brightness * 0.72))
	}
}

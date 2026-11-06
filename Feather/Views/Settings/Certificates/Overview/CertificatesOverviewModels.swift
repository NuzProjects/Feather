import SwiftUI
import NimbleViews

// MARK: - Status
enum CertificateStatus: CaseIterable {
	case active, expiringSoon, expired, revoked

	static let soonDays = 14

	init(_ cert: CertificatePair, now: Date = .now) {
		if cert.revoked {
			self = .revoked
		} else if let expiration = cert.expiration, expiration <= now {
			self = .expired
		} else if let expiration = cert.expiration, expiration.timeIntervalSince(now) < Double(Self.soonDays) * 86400 {
			self = .expiringSoon
		} else {
			self = .active
		}
	}

	var title: String {
		switch self {
		case .active: return .localized("Active")
		case .expiringSoon: return .localized("Expiring Soon")
		case .expired: return .localized("Expired")
		case .revoked: return .localized("Revoked")
		}
	}

	var icon: String {
		switch self {
		case .active: return "checkmark.seal.fill"
		case .expiringSoon: return "clock.badge.exclamationmark.fill"
		case .expired: return "calendar.badge.minus"
		case .revoked: return "xmark.octagon.fill"
		}
	}

	var color: Color {
		switch self {
		case .active: return .green
		case .expiringSoon: return .orange
		case .expired: return .gray
		case .revoked: return .red
		}
	}
}

// MARK: - Helpers
extension Certificate {
	var isDebug: Bool { (Entitlements?["get-task-allow"]?.value as? Bool) == true }

	var profileType: String {
		if ProvisionsAllDevices == true { return .localized("Enterprise") }
		if ProvisionedDevices != nil { return isDebug ? .localized("Development") : .localized("Ad Hoc") }
		return .localized("Distribution")
	}

	var deviceSummary: String {
		if ProvisionsAllDevices == true { return .localized("All devices") }
		let count = ProvisionedDevices?.count ?? 0
		return count == 1 ? .localized("1 device") : .localized("%lld devices", arguments: count)
	}

	func remainingFraction(now: Date = .now) -> Double {
		let total = ExpirationDate.timeIntervalSince(CreationDate)
		guard total > 0 else { return 0 }
		return min(max(ExpirationDate.timeIntervalSince(now) / total, 0), 1)
	}

	struct Capability: Identifiable {
		let id: String
		let title: String
		let icon: String
		let detail: String?
	}

	var capabilities: [Capability] {
		guard let entitlements = Entitlements else { return [] }
		func has(_ key: String) -> Bool { entitlements[key] != nil }
		func count(_ key: String) -> String? {
			guard let array = entitlements[key]?.value as? [Any] else { return nil }
			return array.count == 1 ? .localized("1 group") : .localized("%lld groups", arguments: array.count)
		}
		var result: [Capability] = []
		if let aps = entitlements["aps-environment"]?.value as? String {
			result.append(.init(id: "push", title: .localized("Push Notifications"), icon: "bell.badge.fill", detail: aps.capitalized))
		}
		if has("com.apple.security.application-groups") {
			result.append(.init(id: "groups", title: .localized("App Groups"), icon: "square.stack.3d.up.fill", detail: count("com.apple.security.application-groups")))
		}
		if has("keychain-access-groups") {
			result.append(.init(id: "keychain", title: .localized("Keychain Sharing"), icon: "key.fill", detail: count("keychain-access-groups")))
		}
		if has("com.apple.developer.icloud-container-identifiers") || has("com.apple.developer.ubiquity-kvstore-identifier") {
			result.append(.init(id: "icloud", title: .localized("iCloud"), icon: "icloud.fill", detail: nil))
		}
		if has("com.apple.developer.associated-domains") {
			result.append(.init(id: "domains", title: .localized("Associated Domains"), icon: "link", detail: nil))
		}
		if has("com.apple.developer.kernel.increased-memory-limit") {
			result.append(.init(id: "memory", title: .localized("Increased Memory Limit"), icon: "memorychip.fill", detail: nil))
		}
		if has("com.apple.developer.kernel.extended-virtual-addressing") {
			result.append(.init(id: "vm", title: .localized("Extended Virtual Addressing"), icon: "cpu.fill", detail: nil))
		}
		if has("com.apple.developer.networking.networkextension") {
			result.append(.init(id: "network", title: .localized("Network Extensions"), icon: "network", detail: nil))
		}
		if has("com.apple.developer.healthkit") {
			result.append(.init(id: "health", title: .localized("HealthKit"), icon: "heart.fill", detail: nil))
		}
		if has("com.apple.developer.siri") {
			result.append(.init(id: "siri", title: .localized("Siri"), icon: "mic.fill", detail: nil))
		}
		if has("com.apple.developer.game-center") {
			result.append(.init(id: "gamecenter", title: .localized("Game Center"), icon: "gamecontroller.fill", detail: nil))
		}
		if isDebug {
			result.append(.init(id: "debug", title: .localized("Debugging"), icon: "ladybug.fill", detail: "get-task-allow"))
		}
		return result
	}
}

extension CertificatePair {
	var signedAppsList: [Signed] {
		((signedApps as? Set<Signed>) ?? []).sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
	}
}

// MARK: - Shared style
enum CertificateOverviewStyle {
	static var cornerRadius: CGFloat {
		if #available(iOS 26.0, *) { return 28 } else { return 10.5 }
	}
}

// MARK: - Validity ring
struct CertificateValidityRing: View {
	let expiration: Date?
	let fraction: Double
	var size: CGFloat = 84
	var showsLabel = true

	private var _info: Date.ExpirationInfo? { expiration?.expirationInfo() }
	private var _color: Color { _info?.color ?? .gray }
	private var _lineWidth: CGFloat { max(size * 0.1, 4) }

	var body: some View {
		ZStack {
			Circle()
				.stroke(_color.opacity(0.18), lineWidth: _lineWidth)
			Circle()
				.trim(from: 0, to: fraction)
				.stroke(_color, style: StrokeStyle(lineWidth: _lineWidth, lineCap: .round))
				.rotationEffect(.degrees(-90))
				.animation(.snappy, value: fraction)
			if showsLabel {
				VStack(spacing: 0) {
					Text(_value)
						.font(.system(size: size * 0.26, weight: .bold, design: .rounded))
						.foregroundStyle(_color)
						.contentTransition(.numericText())
					Text(_unit)
						.font(.system(size: max(size * 0.11, 9), weight: .semibold))
						.foregroundStyle(.secondary)
				}
				.minimumScaleFactor(0.6)
				.padding(_lineWidth)
			}
		}
		.frame(width: size, height: size)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(_info?.formatted ?? .localized("Unknown expiry"))
	}

	private var _left: TimeInterval { expiration?.timeIntervalSinceNow ?? 0 }

	private var _value: String {
		guard _left > 0 else { return "0" }
		if _left < 3600 { return "\(Int(_left / 60))" }
		if _left < 86400 { return "\(Int(_left / 3600))" }
		return "\(Int(_left / 86400))"
	}

	private var _unit: String {
		guard _left > 0 else { return .localized("EXPIRED") }
		if _left < 3600 { return .localized("MIN LEFT") }
		if _left < 86400 { return .localized("HRS LEFT") }
		return Int(_left / 86400) == 1 ? .localized("DAY LEFT") : .localized("DAYS LEFT")
	}
}

// MARK: - Status capsule
struct CertificateStatusCapsule: View {
	let status: CertificateStatus

	var body: some View {
		Label(status.title, systemImage: status.icon)
			.font(.caption.bold())
			.foregroundStyle(status.color)
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
			.background(status.color.opacity(0.15))
			.clipShape(Capsule())
	}
}

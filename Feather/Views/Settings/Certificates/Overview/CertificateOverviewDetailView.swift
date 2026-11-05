import SwiftUI
import NimbleViews

// MARK: - View
struct CertificateOverviewDetailView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	@ObservedObject var cert: CertificatePair
	@State private var _data: Certificate?
	@State private var _isCheckingRevocation = false

	private var _index: Int? {
		Storage.shared.getAllCertificates().firstIndex { $0.uuid == cert.uuid }
	}

	// MARK: Body
	var body: some View {
		NBList(cert.nickname ?? _data?.Name ?? .localized("Certificate"), displayMode: .inline) {
			_header()

			if let data = _data {
				_validitySection(data)
				_capabilitiesSection(data)
				_devicesSection(data)
			}

			_appsSection()
			_actionsSection()
		}
		.onAppear {
			_data = Storage.shared.getProvisionFileDecoded(for: cert)
		}
	}
}

// MARK: - Extension: View
extension CertificateOverviewDetailView {
	@ViewBuilder
	private func _header() -> some View {
		Section {
			VStack(spacing: 10) {
				CertificateValidityRing(expiration: cert.expiration, fraction: _data?.remainingFraction() ?? 0, size: 140)
					.padding(.bottom, 4)
				Text(cert.nickname ?? _data?.Name ?? .localized("Unknown"))
					.font(.title3.bold())
					.multilineTextAlignment(.center)
				if let team = _data?.TeamName {
					Text(team)
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				HStack(spacing: 6) {
					CertificateStatusCapsule(status: CertificateStatus(cert))
					if _index == _storedSelectedCert {
						Label("In Use", systemImage: "checkmark.circle.fill")
							.font(.caption.bold())
							.foregroundStyle(Color.accentColor)
							.padding(.horizontal, 10)
							.padding(.vertical, 5)
							.background(Color.accentColor.opacity(0.15))
							.clipShape(Capsule())
					}
				}
			}
			.frame(maxWidth: .infinity)
		}
		.listRowBackground(Color.clear)
	}

	@ViewBuilder
	private func _validitySection(_ data: Certificate) -> some View {
		NBSection("Validity") {
			_info("Created", data.CreationDate.formatted(date: .abbreviated, time: .shortened))
			_info("Expires", data.ExpirationDate.formatted(date: .abbreviated, time: .shortened))
			_info("Valid For", "\(max(Int(data.ExpirationDate.timeIntervalSince(data.CreationDate) / 86400), 0)) days")
			LabeledContent("Time Left") {
				Text(data.ExpirationDate.expirationInfo().formatted)
					.foregroundStyle(data.ExpirationDate.expirationInfo().color)
					.bold()
			}
			_info("Profile Type", data.profileType)
			_info("Revoked", cert.revoked ? "Yes" : "No")
			if let ppq = data.PPQCheck {
				_info("PPQCheck", ppq ? "Yes" : "No")
			}
		} footer: {
			Text("Feather notifies you 3 days and 1 day before the certificate in use expires, and checks for revocation in the background.")
		}
	}

	@ViewBuilder
	private func _capabilitiesSection(_ data: Certificate) -> some View {
		let capabilities = data.capabilities
		NBSection("Capabilities", secondary: capabilities.isEmpty ? nil : "\(capabilities.count)") {
			if capabilities.isEmpty {
				Text("No special capabilities.")
					.foregroundStyle(.secondary)
			}
			ForEach(capabilities) { capability in
				HStack(spacing: 12) {
					Image(systemName: capability.icon)
						.font(.system(size: 14, weight: .semibold))
						.foregroundStyle(.white)
						.frame(width: 28, height: 28)
						.background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.accentColor))
					Text(capability.title)
					Spacer()
					if let detail = capability.detail {
						Text(detail)
							.font(.footnote)
							.foregroundStyle(.secondary)
					}
				}
			}
			if let entitlements = data.Entitlements {
				NavigationLink {
					CertificatesInfoEntitlementView(entitlements: entitlements)
				} label: {
					Text("All Entitlements")
						.badge(entitlements.count)
				}
			}
		}
	}

	@ViewBuilder
	private func _devicesSection(_ data: Certificate) -> some View {
		NBSection("Devices") {
			if data.ProvisionsAllDevices == true {
				Label("Installs on any device", systemImage: "infinity")
			} else if let devices = data.ProvisionedDevices, !devices.isEmpty {
				DisclosureGroup {
					ForEach(devices, id: \.self) { udid in
						Text(udid)
							.font(.system(.footnote, design: .monospaced))
							.foregroundStyle(.secondary)
							.copyableText(udid)
					}
				} label: {
					Label(data.deviceSummary, systemImage: "iphone")
				}
			} else {
				Label("No devices listed", systemImage: "iphone.slash")
					.foregroundStyle(.secondary)
			}
		} footer: {
			Text("Apps signed with this certificate only open on devices listed in its provisioning profile.")
		}
	}

	@ViewBuilder
	private func _appsSection() -> some View {
		let apps = cert.signedAppsList
		NBSection("Signed Apps", secondary: apps.isEmpty ? nil : "\(apps.count)") {
			if apps.isEmpty {
				Text("No apps signed with this certificate yet.")
					.foregroundStyle(.secondary)
			}
			ForEach(apps, id: \.objectID) { app in
				HStack(spacing: 12) {
					FRAppIconView(app: app, size: 40)
					VStack(alignment: .leading, spacing: 2) {
						Text(app.name ?? .localized("Unknown"))
							.lineLimit(1)
						Text([app.version, app.identifier].compactMap { $0 }.joined(separator: " · "))
							.font(.footnote)
							.foregroundStyle(.secondary)
							.lineLimit(1)
					}
					Spacer()
					if let date = app.date {
						Text(date, style: .relative)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
			}
		} footer: {
			if !apps.isEmpty, CertificateStatus(cert) != .active {
				Text("These apps stop opening once the certificate expires or is revoked. Re-sign them with another certificate to keep using them.")
			}
		}
	}

	@ViewBuilder
	private func _actionsSection() -> some View {
		Section {
			if let index = _index, index != _storedSelectedCert {
				Button("Use This Certificate", systemImage: "checkmark.circle") {
					_storedSelectedCert = index
					CertificateExpiry.refresh()
					UINotificationFeedbackGenerator().notificationOccurred(.success)
				}
			}
			Button("Check Revocation", systemImage: "person.text.rectangle") {
				Storage.shared.revokagedCertificate(for: cert)
				UIImpactFeedbackGenerator(style: .light).impactOccurred()
			}
			.disabled(cert.revoked)
			if let directory = Storage.shared.getUuidDirectory(for: cert), let shared = directory.toSharedDocumentsURL() {
				Button(.localized("Open in Files"), systemImage: "folder") {
					UIApplication.open(shared)
				}
			}
		}
	}

	@ViewBuilder
	private func _info(_ title: String, _ value: String) -> some View {
		LabeledContent(title) {
			Text(value)
		}
		.copyableText(value)
	}
}

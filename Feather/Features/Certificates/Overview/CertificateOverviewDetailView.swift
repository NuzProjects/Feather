import SwiftUI
import NimbleViews
import Zsign

struct CertificateOverviewDetailView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	@ObservedObject var cert: CertificatePair
	@State private var _data: Certificate?
	@ScaledMetric private var _capabilityTile: CGFloat = 28
	@ScaledMetric private var _capabilitySymbol: CGFloat = 14
	@State private var _isCheckingRevocation = false
	@State private var _revocationAlert: (title: String, message: String)?

	private var _index: Int? {
		Storage.shared.getAllCertificates().firstIndex { $0.uuid == cert.uuid }
	}

	var body: some View {
		NBList(cert.nickname ?? _data?.Name ?? AppleIDAccount.marker(for: cert)?.appleID ?? .localized("Certificate"), displayMode: .inline) {
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
		.alert(
			_revocationAlert?.title ?? "",
			isPresented: Binding(get: { _revocationAlert != nil }, set: { if !$0 { _revocationAlert = nil } })
		) {
			Button("OK") { _revocationAlert = nil }
		} message: {
			Text(_revocationAlert?.message ?? "")
		}
	}
}

extension CertificateOverviewDetailView {
	@ViewBuilder
	private func _header() -> some View {
		Section {
			VStack(spacing: 10) {
				CertificateValidityRing(expiration: cert.expiration, fraction: _data?.remainingFraction() ?? 0, size: 140)
					.padding(.bottom, 4)
				Text(cert.nickname ?? _data?.Name ?? AppleIDAccount.marker(for: cert)?.appleID ?? .localized("Unknown"))
					.font(.title3.bold())
					.multilineTextAlignment(.center)
				if let team = _data?.TeamName ?? AppleIDAccount.marker(for: cert)?.teamName {
					Text(team)
						.font(.subheadline)
						.foregroundStyle(Color(uiColor: .secondaryLabel))
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
		NBSection(.localized("Validity")) {
			_info(.localized("Created"), data.CreationDate.formatted(date: .abbreviated, time: .shortened))
			_info(.localized("Expires"), data.ExpirationDate.formatted(date: .abbreviated, time: .shortened))
			_info(.localized("Valid For"), .localized("%lld days", arguments: max(Int(data.ExpirationDate.timeIntervalSince(data.CreationDate) / 86400), 0)))
			LabeledContent("Time Left") {
				Text(data.ExpirationDate.expirationInfo().formatted)
					.foregroundStyle(data.ExpirationDate.expirationInfo().color)
					.bold()
			}
			_info(.localized("Profile Type"), data.profileType)
			_info(.localized("Revoked"), cert.revoked ? .localized("Yes") : .localized("No"))
			if let ppq = data.PPQCheck {
				_info(.localized("PPQCheck"), ppq ? .localized("Yes") : .localized("No"))
			}
		} footer: {
			Text("Feather notifies you 3 days and 1 day before the certificate in use expires, and checks for revocation in the background.")
		}
	}

	@ViewBuilder
	private func _capabilitiesSection(_ data: Certificate) -> some View {
		let capabilities = data.capabilities
		NBSection(.localized("Capabilities"), secondary: capabilities.isEmpty ? nil : "\(capabilities.count)") {
			if capabilities.isEmpty {
				Text("No special capabilities.")
					.foregroundStyle(Color(uiColor: .secondaryLabel))
			}
			ForEach(capabilities) { capability in
				HStack(spacing: 12) {
					Image(systemName: capability.icon)
						.font(.system(size: _capabilitySymbol, weight: .semibold))
						.foregroundStyle(.white)
						.frame(width: _capabilityTile, height: _capabilityTile)
						.background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.accentColor))
					Text(capability.title)
					Spacer()
					if let detail = capability.detail {
						Text(detail)
							.font(.footnote)
							.foregroundStyle(Color(uiColor: .secondaryLabel))
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
		NBSection(.localized("Devices")) {
			if data.ProvisionsAllDevices == true {
				Label("Installs on any device", systemImage: "infinity")
			} else if let devices = data.ProvisionedDevices, !devices.isEmpty {
				DisclosureGroup {
					ForEach(devices, id: \.self) { udid in
						Text(udid)
							.font(.system(.footnote, design: .monospaced))
							.foregroundStyle(Color(uiColor: .secondaryLabel))
							.copyableText(udid)
					}
				} label: {
					Label(data.deviceSummary, systemImage: "iphone")
				}
			} else {
				Label("No devices listed", systemImage: "iphone.slash")
					.foregroundStyle(Color(uiColor: .secondaryLabel))
			}
		} footer: {
			Text("Apps signed with this certificate only open on devices listed in its provisioning profile.")
		}
	}

	@ViewBuilder
	private func _appsSection() -> some View {
		let apps = cert.signedAppsList
		NBSection(.localized("Signed Apps"), secondary: apps.isEmpty ? nil : "\(apps.count)") {
			if apps.isEmpty {
				Text("No apps signed with this certificate yet.")
					.foregroundStyle(Color(uiColor: .secondaryLabel))
			}
			ForEach(apps, id: \.objectID) { app in
				HStack(spacing: 12) {
					FRAppIconView(app: app, size: 40)
					VStack(alignment: .leading, spacing: 2) {
						Text(app.name ?? .localized("Unknown"))
							.lineLimit(1)
						Text([app.version, app.identifier].compactMap { $0 }.joined(separator: " · "))
							.font(.footnote)
							.foregroundStyle(Color(uiColor: .secondaryLabel))
							.lineLimit(1)
					}
					Spacer()
					if let date = app.date {
						Text(date, style: .relative)
							.font(.caption)
							.foregroundStyle(Color(uiColor: .secondaryLabel))
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
			Button {
				_checkRevocation()
			} label: {
				HStack {
					Label("Check Revocation", systemImage: "person.text.rectangle")
					Spacer()
					if _isCheckingRevocation { ProgressView() }
				}
			}
			if let directory = Storage.shared.getUuidDirectory(for: cert), let shared = directory.toSharedDocumentsURL() {
				Button(.localized("Open in Files"), systemImage: "folder") {
					UIApplication.open(shared)
				}
			}
		}
	}

	private func _checkRevocation() {
		guard !_isCheckingRevocation else { return }
		_isCheckingRevocation = true
		let name = cert.nickname ?? _data?.Name ?? AppleIDAccount.marker(for: cert)?.appleID ?? .localized("This certificate")
		let provision = Storage.shared.getFile(.provision, from: cert)?.path ?? ""
		let p12 = Storage.shared.getFile(.certificate, from: cert)?.path ?? ""
		let password = cert.password ?? ""
		DispatchQueue.global(qos: .userInitiated).async {
			Zsign.checkRevokage(provisionPath: provision, p12Path: p12, p12Password: password) { status, _, error in
				DispatchQueue.main.async {
					_isCheckingRevocation = false
					switch status {
					case 0:
						if cert.revoked { cert.revoked = false; Storage.shared.saveContext() }
						UINotificationFeedbackGenerator().notificationOccurred(.success)
						_revocationAlert = (.localized("Not Revoked"), .localized("%@ is valid and hasn't been revoked.", arguments: name))
					case 1:
						cert.revoked = true
						Storage.shared.saveContext()
						UINotificationFeedbackGenerator().notificationOccurred(.error)
						_revocationAlert = (.localized("Revoked"), .localized("Apple revoked %@. Apps signed with it won't open anymore, so add a new certificate.", arguments: name))
					default:
						UINotificationFeedbackGenerator().notificationOccurred(.warning)
						DevLog.shared.log(.error, "Revocation check failed: \(error ?? "unknown error")", category: "Certificates")
						_revocationAlert = (.localized("Couldn't Check"), error ?? .localized("Try again in a moment."))
					}
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

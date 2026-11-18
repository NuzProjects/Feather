import SwiftUI
import NimbleViews
import Zsign

struct CertificatesInfoView: View {
	@Environment(\.dismiss) var dismiss
	@State var data: Certificate?
	@State private var _appleID: AppleIDMarker?

	var cert: CertificatePair

	var body: some View {
		NBNavigationView(cert.nickname ?? "", displayMode: .inline) {
			Form {
				Section {} header: {
					Image("Cert")
						.resizable()
						.scaledToFit()
						.frame(width: 107, height: 107)
						.frame(maxWidth: .infinity, alignment: .center)
				}

				if let appleID = _appleID {
					NBSection(.localized("Apple ID")) {
						_info(.localized("Name"), description: appleID.displayName)
						_info(.localized("Apple ID"), description: appleID.appleID)
						_info(.localized("Team Name"), description: appleID.teamName)
						_info(.localized("Team ID"), description: appleID.teamID)
					}
					Section {
						if let expiration = cert.expiration {
							_info(.localized("Certificate Expires"), description: expiration.expirationInfo().formatted)
						}
						_info(.localized("Signed Apps Last"), description: String.localized("7 days"))
						_info(.localized("Revoked"), description: cert.revoked ? "✓" : "✗")
					} footer: {
						Text(.localized("Each app gets its own provisioning profile from Apple when you sign it. Re-sign apps before 7 days pass to keep them opening."))
					}
				}

				if let data {
					_infoSection(data: data)
					_entitlementsSection(data: data)
					_miscSection(data: data)
				}

				Section {
					Button(.localized("Open in Files"), systemImage: "folder") {
						if let url = Storage.shared.getUuidDirectory(for: cert)?.toSharedDocumentsURL() { UIApplication.open(url) }
					}
				}
			}
			.toolbar {
				NBToolbarButton(role: .close)
			}
		}
		.onAppear {
			data = Storage.shared.getProvisionFileDecoded(for: cert)
			_appleID = AppleIDAccount.marker(for: cert)
		}
	}
}

extension CertificatesInfoView {
	@ViewBuilder
	private func _infoSection(data: Certificate) -> some View {
		NBSection(.localized("Info")) {
			_info(.localized("Name"), description: data.Name)
			_info(.localized("AppID Name"), description: data.AppIDName)
			_info(.localized("Team Name"), description: data.TeamName)
		}

		Section {
			_info(.localized("Expires"), description: data.ExpirationDate.expirationInfo().formatted)
				.foregroundStyle(data.ExpirationDate.expirationInfo().color)

			_info(.localized("Revoked"), description: cert.revoked ? "✓" : "✗")

			if let ppq = data.PPQCheck {
				_info(.localized("PPQCheck"), description: ppq ? "✓" : "✗")
			}
		}
	}

	@ViewBuilder
	private func _entitlementsSection(data: Certificate) -> some View {
		if let entitlements = data.Entitlements {
			Section {
				NavigationLink(.localized("View Entitlements")) {
					CertificatesInfoEntitlementView(entitlements: entitlements)
				}
			}
		}
	}

	@ViewBuilder
	private func _miscSection(data: Certificate) -> some View {
		NBSection(.localized("Misc")) {
			_disclosure(.localized("Platform"), keys: data.Platform)

			if let all = data.ProvisionsAllDevices {
				_info(.localized("Provision All Devices"), description: all.description)
			}

			if let devices = data.ProvisionedDevices {
				_disclosure(.localized("Provisioned Devices"), keys: devices)
			}

			_disclosure(.localized("Team Identifiers"), keys: data.TeamIdentifier)

			if let prefix = data.ApplicationIdentifierPrefix{
				_disclosure(.localized("Identifier Prefix"), keys: prefix)
			}
		}
	}

	@ViewBuilder
	private func _info(_ title: String, description: String) -> some View {
		LabeledContent(title) {
			Text(description)
		}
		.copyableText(description)
	}

	@ViewBuilder
	private func _disclosure(_ title: String, keys: [String]) -> some View {
		DisclosureGroup(title) {
			ForEach(keys, id: \.self) { key in
				Text(key)
					.foregroundStyle(Color(uiColor: .secondaryLabel))
					.copyableText(key)
			}
		}
	}
}

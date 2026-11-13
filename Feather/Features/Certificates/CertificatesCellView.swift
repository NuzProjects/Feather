import SwiftUI
import NimbleViews

struct CertificatesCellView: View {
	@State var data: Certificate?
	@State private var _appleID: AppleIDMarker?

	@ObservedObject var cert: CertificatePair

	var body: some View {
		VStack(spacing: 6) {
			let title = {
				let teamName = data?.TeamName.trimmingCharacters(in: .whitespaces) ?? ""
				let fallbackName: String? = teamName.isEmpty ? data?.Name : teamName
				var title: String = cert.nickname ?? fallbackName ?? _appleID?.appleID ?? String.localized("Unknown")

				if let getTaskAllow = data?.Entitlements?["get-task-allow"]?.value as? Bool, getTaskAllow == true {
					title = "🐞 \(title)"
				}

				return title
			}()

			NBTitleWithSubtitleView(
				title: title,
				subtitle: _subtitle
			)

			_certInfoPill(data: cert)
		}
		.frame(height: 80)
		.contentTransition(.opacity)
		.frame(maxWidth: .infinity, alignment: .leading)
		.onAppear {
			withAnimation {
				data = Storage.shared.getProvisionFileDecoded(for: cert)
				_appleID = AppleIDAccount.marker(for: cert)
			}
		}
	}
}

extension CertificatesCellView {
	private var _subtitle: String {
		if let appleID = _appleID { return String(format: String.localized("Apple ID · Team %@"), appleID.teamID) }
		if let team = data?.TeamIdentifier.first { return String(format: String.localized("Team %@"), team) }
		return data?.AppIDName ?? String.localized("Unknown")
	}

	@ViewBuilder
	private func _certInfoPill(data: CertificatePair) -> some View {
		let pillItems = _buildPills(from: data)
		HStack(spacing: 6) {
			ForEach(pillItems.indices, id: \.hashValue) { index in
				let pill = pillItems[index]
				NBPillView(
					title: pill.title,
					icon: pill.icon,
					color: pill.color,
					index: index,
					count: pillItems.count
				)
			}
		}
	}

	private func _buildPills(from cert: CertificatePair) -> [NBPillItem] {
		var pills: [NBPillItem] = []

		if cert.ppQCheck == true {
			pills.append(NBPillItem(title: .localized("PPQCheck"), icon: "checkmark.shield", color: .red))
		}

		if cert.revoked == true {
			pills.append(NBPillItem(title: .localized("Revoked"), icon: "xmark.octagon", color: .red))
		}

		if _appleID != nil {
			pills.append(NBPillItem(title: .localized("Apple ID"), icon: "person.crop.circle", color: .accentColor))
			pills.append(NBPillItem(title: .localized("Apps Last 7 Days"), icon: "clock.arrow.circlepath", color: .orange))
			return pills
		}

		if let info = cert.expiration?.expirationInfo() {
			pills.append(NBPillItem(
				title: info.formatted,
				icon: info.icon,
				color: info.color
			))
		}

		return pills
	}
}

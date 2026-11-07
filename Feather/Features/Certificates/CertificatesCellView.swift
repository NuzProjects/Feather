import SwiftUI
import NimbleViews

struct CertificatesCellView: View {
	@State var data: Certificate?

	@ObservedObject var cert: CertificatePair

	var body: some View {
		VStack(spacing: 6) {
			let title = {
				let teamName = data?.TeamName.trimmingCharacters(in: .whitespaces) ?? ""
				let fallbackName: String? = teamName.isEmpty ? data?.Name : teamName
				var title: String = cert.nickname ?? fallbackName ?? String.localized("Unknown")

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
			}
		}
	}
}

extension CertificatesCellView {
	private var _subtitle: String {
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

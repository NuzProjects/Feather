import SwiftUI
import NimbleViews

struct CertificatesInfoEntitlementView: View {
	let entitlements: [String: AnyCodable]

	var body: some View {
		NBList(.localized("Entitlements")) {
			ForEach(entitlements.keys.sorted(), id: \.self) { key in
				if let value = entitlements[key]?.value {
					CertificatesInfoEntitlementCellView(key: key, value: value)
				}
			}
		}
		.listStyle(.grouped)
	}
}

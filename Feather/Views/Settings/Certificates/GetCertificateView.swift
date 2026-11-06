import SwiftUI
import NimbleViews

// MARK: - Providers
/// Where people can get a signing certificate. Edit this list to change what the sheet shows.
enum CertificateProvider: CaseIterable, Identifiable {
	case appleDeveloper
	case signulous
	case udidRegistrations
	case kravaSign

	var id: Self { self }

	var name: String {
		switch self {
		case .appleDeveloper: "Apple Developer Program"
		case .signulous: "Signulous"
		case .udidRegistrations: "UDID Registrations"
		case .kravaSign: "KravaSign"
		}
	}

	var detail: String {
		switch self {
		case .appleDeveloper: "Your own certificate straight from Apple. $99 a year."
		case .signulous: "Certificates registered to your device, with their own signing app."
		case .udidRegistrations: "Registers your device on a developer account and sends you the certificate files."
		case .kravaSign: "Device certificates you can import straight into Feather."
		}
	}

	var icon: String {
		switch self {
		case .appleDeveloper: "apple.logo"
		case .signulous: "signature"
		case .udidRegistrations: "iphone.badge.checkmark"
		case .kravaSign: "checkmark.seal.fill"
		}
	}

	var url: URL {
		switch self {
		case .appleDeveloper: URL(string: "https://developer.apple.com/programs/enroll/")!
		case .signulous: URL(string: "https://www.signulous.com")!
		case .udidRegistrations: URL(string: "https://www.udidregistrations.com")!
		case .kravaSign: URL(string: "https://kravasign.com")!
		}
	}

	var isOfficial: Bool { self == .appleDeveloper }
}

// MARK: - View
struct GetCertificateView: View {
	@Environment(\.dismiss) private var dismiss
	@State private var _isImportPresenting = false

	// MARK: Body
	var body: some View {
		NBNavigationView("Get a Certificate", displayMode: .inline) {
			Form {
				Section {
					VStack(spacing: 10) {
						Image("Cert")
							.resizable()
							.scaledToFit()
							.frame(width: 72, height: 72)
						Text("Feather signs apps with your own certificate. Get one from Apple or a provider below, then import it here.")
							.font(.subheadline)
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.center)
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, 4)
				}
				.listRowBackground(Color.clear)

				NBSection("Official") {
					ForEach(CertificateProvider.allCases.filter(\.isOfficial)) { _row($0) }
				}

				NBSection("Providers") {
					ForEach(CertificateProvider.allCases.filter { !$0.isOfficial }) { _row($0) }
				} footer: {
					Text("These are independent sellers, not part of Feather. Check their prices and refund policy before you buy.")
				}

				Section {
					Button {
						_isImportPresenting = true
					} label: {
						Label("Import Certificate", systemImage: "square.and.arrow.down")
					}
				} header: {
					Text("Already Have One?")
				} footer: {
					Text("You'll need the .p12 file, its password, and the .mobileprovision file.")
				}
			}
			.toolbar {
				NBToolbarButton(role: .close)
			}
			.sheet(isPresented: $_isImportPresenting) {
				CertificatesAddView()
					.presentationDetents([.medium])
			}
		}
	}
}

// MARK: - Extension: View
extension GetCertificateView {
	@ViewBuilder
	private func _row(_ provider: CertificateProvider) -> some View {
		Button {
			UIApplication.open(provider.url)
		} label: {
			HStack(spacing: 14) {
				Image(systemName: provider.icon)
					.font(.system(size: 17, weight: .semibold))
					.foregroundStyle(.white)
					.frame(width: 36, height: 36)
					.background(
						RoundedRectangle(cornerRadius: 9, style: .continuous)
							.fill(provider.isOfficial ? Color.black : Color.accentColor)
					)
				VStack(alignment: .leading, spacing: 2) {
					Text(provider.name)
						.foregroundStyle(.primary)
					Text(provider.detail)
						.font(.footnote)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}
				Spacer(minLength: 8)
				Image(systemName: "arrow.up.right")
					.font(.footnote.weight(.semibold))
					.foregroundStyle(.secondary)
			}
			.padding(.vertical, 2)
		}
	}
}

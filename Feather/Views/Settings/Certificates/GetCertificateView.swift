import SwiftUI
import NimbleViews
import NukeUI

// MARK: - Providers
enum CertificateProviders {
	typealias Provider = RemoteConfigData.Provider

	static let builtIn: [Provider] = [
		Provider(name: "Apple Developer Program", detail: "Your own certificate straight from Apple. $99 a year.", url: URL(string: "https://developer.apple.com/programs/enroll/")!, icon: "apple.logo", official: true),
		Provider(name: "Signulous", detail: "Certificates registered to your device, with their own signing app.", url: URL(string: "https://www.signulous.com")!, icon: "signature", official: false, iconURL: URL(string: "https://www.signulous.com/apple-touch-icon.png")),
		Provider(name: "UDID Registrations", detail: "Registers your device on a developer account and sends you the certificate files.", url: URL(string: "https://www.udidregistrations.com")!, icon: "iphone.badge.checkmark", official: false, iconURL: URL(string: "https://www.udidregistrations.com/apple-touch-icon.png")),
		Provider(name: "KravaSign", detail: "Device certificates you can import straight into Feather.", url: URL(string: "https://www.kravasign.com")!, icon: "checkmark.seal.fill", official: false, iconURL: URL(string: "https://www.kravasign.com/images/logo.png"))
	]

	@MainActor
	static var current: [Provider] {
		if let remote = RemoteConfig.shared.data.certificateProviders, !remote.isEmpty { return remote }
		return builtIn
	}
}

// MARK: - View
struct GetCertificateView: View {
	@Environment(\.dismiss) private var dismiss
	@ObservedObject private var _remote = RemoteConfig.shared
	@State private var _isImportPresenting = false
	@State private var _certificateCountBeforeImport = 0

	private var _providers: [CertificateProviders.Provider] { CertificateProviders.current }

	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Get a Certificate"), displayMode: .inline) {
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

				if _providers.contains(where: { $0.official == true }) {
					NBSection(.localized("Official")) {
						ForEach(_providers.filter { $0.official == true }) { _row($0) }
					}
				}

				NBSection(.localized("Unofficial Providers")) {
					ForEach(_providers.filter { $0.official != true }) { _row($0) }
				} footer: {
					Text("These are independent sellers, not part of Feather. Check their prices and refund policy before you buy.")
				}

				Section {
					Button {
						_certificateCountBeforeImport = Storage.shared.getAllCertificates().count
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
			.sheet(isPresented: $_isImportPresenting, onDismiss: {
				if Storage.shared.getAllCertificates().count > _certificateCountBeforeImport {
					dismiss()
				}
			}) {
				CertificatesAddView()
					.presentationDetents([.medium])
			}
		}
	}
}

// MARK: - Extension: View
extension GetCertificateView {
	@ViewBuilder
	private func _icon(for provider: CertificateProviders.Provider) -> some View {
		let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
		let symbol = Image(systemName: provider.icon ?? "link")
			.font(.system(size: 17, weight: .semibold))
			.foregroundStyle(.white)
			.frame(width: 36, height: 36)
			.background(shape.fill(provider.official == true ? AnyShapeStyle(Color.black) : AnyShapeStyle(TintShapeStyle())))

		if let iconURL = provider.iconURL {
			LazyImage(url: iconURL) { state in
				if let image = state.image {
					image
						.resizable()
						.scaledToFill()
						.frame(width: 36, height: 36)
						.clipShape(shape)
						.overlay(shape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
				} else {
					symbol
				}
			}
			.frame(width: 36, height: 36)
		} else {
			symbol
		}
	}

	@ViewBuilder
	private func _row(_ provider: CertificateProviders.Provider) -> some View {
		Button {
			UIApplication.open(provider.url)
		} label: {
			HStack(spacing: 14) {
				_icon(for: provider)
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

import SwiftUI
import NimbleViews
import UniformTypeIdentifiers

struct CertificatesAddView: View {
	@Environment(\.dismiss) private var dismiss

	@State private var _p12URL: URL? = nil
	@State private var _provisionURL: URL? = nil
	@State private var _p12Password: String = ""
	@State private var _certificateName: String = ""

	@State private var _isImportingP12Presenting = false
	@State private var _isImportingMobileProvisionPresenting = false
	@State private var _isAppleIDPresenting = false

	var saveButtonDisabled: Bool {
		_p12URL == nil || _provisionURL == nil
	}

	var body: some View {
		NBNavigationView(_isAppleIDPresenting ? String.localized("Apple ID") : String.localized("New Certificate"), displayMode: .inline) {
			if _isAppleIDPresenting {
				AppleIDSignInView { dismiss() }
					.toolbar {
						NBToolbarButton(String.localized("Back"), systemImage: "chevron.left", style: .icon, placement: .cancellationAction) {
							withAnimation(.snappy) { _isAppleIDPresenting = false }
						}
					}
					.transition(.move(edge: .trailing).combined(with: .opacity))
			} else {
			Form {
				Section {
					Button {
						withAnimation(.snappy) { _isAppleIDPresenting = true }
					} label: {
						HStack {
							Label(.localized("Sign In with Apple ID"), systemImage: "person.crop.circle.badge.plus")
							Spacer()
							Image(systemName: "chevron.right")
								.font(.footnote.weight(.semibold))
								.foregroundStyle(.tertiary)
						}
					}
				} footer: {
					Text(.localized("No certificate? Sign in with a free Apple ID instead. Apps signed this way last 7 days."))
				}

				NBSection(.localized("Files")) {
					_importButton(.localized("Import Certificate File"), file: _p12URL) {
						_isImportingP12Presenting = true
					}
					_importButton(.localized("Import Provisioning File"), file: _provisionURL) {
						_isImportingMobileProvisionPresenting = true
					}
				}
				NBSection(.localized("Password")) {
					SecureField(.localized("Enter Password"), text: $_p12Password)
				} footer: {
					Text(.localized("Enter the password associated with the private key. Leave it blank if theres no password required."))
				}

				Section {
					TextField(.localized("Nickname (Optional)"), text: $_certificateName)
				}
			}
			.toolbar {
				NBToolbarButton(role: .cancel)

				NBToolbarButton(
					.localized("Save"),
					style: .text,
					placement: .confirmationAction,
					isDisabled: saveButtonDisabled
				) {
					_saveCertificate()
				}
			}
			.sheet(isPresented: $_isImportingP12Presenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.p12],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self._p12URL = selectedFileURL
					}
				)
				.ignoresSafeArea()
			}
			.sheet(isPresented: $_isImportingMobileProvisionPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.mobileProvision],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self._provisionURL = selectedFileURL
					}
				)
				.ignoresSafeArea()
			}
			.transition(.move(edge: .leading).combined(with: .opacity))
			}
		}
	}
}

extension CertificatesAddView {
	@ViewBuilder
	private func _importButton(
		_ title: String,
		file: URL?,
		action: @escaping () -> Void
	) -> some View {
		Button(title) {
			action()
		}
		.foregroundColor(file == nil ? .accentColor : .disabled())
		.disabled(file != nil)
		.animation(.easeInOut(duration: 0.3), value: file != nil)
	}
}

extension CertificatesAddView {
	private func _saveCertificate() {
		guard
			let p12URL = _p12URL,
			let provisionURL = _provisionURL,
			FR.checkPasswordForCertificate(for: p12URL, with: _p12Password, using: provisionURL)
		else {
			UIAlertController.showAlertWithOk(
				title: .localized("Bad Password"),
				message: .localized("Please check the password and try again.")
			)
			return
		}

		FR.handleCertificateFiles(
			p12URL: p12URL,
			provisionURL: provisionURL,
			p12Password: _p12Password,
			certificateName: _certificateName
		) { error in
			if let error {
				UIAlertController.showAlertWithOk(title: .localized("Error"), message: error.localizedDescription)
			} else {
				dismiss()
			}
		}
	}
}

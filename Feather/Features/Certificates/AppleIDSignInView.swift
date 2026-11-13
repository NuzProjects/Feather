import SwiftUI
import NimbleViews

struct AppleIDSignInView: View {
	var onFinish: () -> Void

	@State private var _appleID = ""
	@State private var _password = ""
	@State private var _udid = AppleIDAccount.knownUDID?.value ?? ""
	@State private var _udidSource = AppleIDAccount.knownUDID?.source
	@State private var _isWorking = false
	@State private var _isFindingUDID = false

	private var _trimmedAppleID: String { _appleID.trimmingCharacters(in: .whitespacesAndNewlines) }
	private var _trimmedUDID: String { _udid.trimmingCharacters(in: .whitespacesAndNewlines) }

	private var _canSignIn: Bool {
		!_isWorking && !_trimmedAppleID.isEmpty && !_password.isEmpty && _trimmedUDID.count >= 24
	}

	var body: some View {
		Form {
			NBSection(.localized("Apple ID")) {
				TextField(.localized("Email or Phone Number"), text: $_appleID)
					.textContentType(.username)
					.keyboardType(.emailAddress)
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled()
				SecureField(.localized("Password"), text: $_password)
					.textContentType(.password)
			} footer: {
				Text(.localized("Your Apple ID and password go only to Apple and are kept in this device's Keychain. A sign-in helper server identifies this device to Apple, but it never sees your password."))
			}

			NBSection(.localized("Device")) {
				TextField(.localized("UDID"), text: $_udid)
					.textInputAutocapitalization(.characters)
					.autocorrectionDisabled()
				if _udidSource == nil {
					Button {
						_isFindingUDID = true
					} label: {
						Label(.localized("Find My UDID"), systemImage: "wand.and.stars")
					}
				}
			} footer: {
				switch _udidSource {
				case .pairing:
					Text(.localized("Filled in from your pairing file."))
				case .profile:
					EmptyView()
				case nil:
					Text(.localized("Apple needs this device's UDID to register it. Tap Find My UDID and allow the download, then open Settings, tap Profile Downloaded and Install. Nothing stays installed, and Settings brings you straight back here with your UDID filled in."))
				}
			}

			Section {
				Button {
					_signIn()
				} label: {
					HStack {
						Text(.localized("Sign In"))
						Spacer()
						if _isWorking {
							ProgressView()
						}
					}
				}
				.disabled(!_canSignIn)
			} footer: {
				Text(.localized("Free Apple IDs have limits: signed apps last 7 days, up to 3 can be installed at once, and up to 10 new apps can be added per week. Apps get a bundle ID ending in your team ID."))
			}
		}
		.interactiveDismissDisabled(_isWorking)
		.onReceive(NotificationCenter.default.publisher(for: AppleIDAccount.detectedUDIDNotification)) { note in
			if let udid = note.object as? String {
				_udid = udid
				_udidSource = .profile
				_isFindingUDID = false
			}
		}
		.sheet(isPresented: $_isFindingUDID) {
			SafariRepresentableView(url: AppleIDAccount.udidProfileURL)
				.ignoresSafeArea()
		}
	}

	private func _signIn() {
		let appleID = _trimmedAppleID
		let password = _password
		let udid = _trimmedUDID
		_isWorking = true
		Task {
			do {
				try await AppleIDAccount.signIn(
					appleID: appleID,
					password: password,
					udid: udid,
					code: { bySMS in
						await AppleIDCodePrompt.ask(appleID: appleID, bySMS: bySMS)
					},
					confirmRevoke: { count in
						await AppleIDCodePrompt.confirmRevoke(count: count)
					}
				)
				await MainActor.run {
					_isWorking = false
					UINotificationFeedbackGenerator().notificationOccurred(.success)
					onFinish()
				}
			} catch {
				await MainActor.run {
					_isWorking = false
					UINotificationFeedbackGenerator().notificationOccurred(.error)
					UIAlertController.showAlertWithOk(
						title: .localized("Couldn't Sign In"),
						message: error.localizedDescription
					)
				}
			}
		}
	}
}

extension AppleIDCodePrompt {
	@MainActor
	static func confirmRevoke(count: Int) async -> Bool {
		await withCheckedContinuation { continuation in
			let alert = UIAlertController(
				title: .localized("Replace Certificate?"),
				message: String(format: .localized("This Apple ID already has %lld development certificates and free accounts can't make more. Feather can revoke them to make its own, but apps signed with them, for example by AltStore or Sideloadly, will stop opening."), count),
				preferredStyle: .alert
			)
			alert.addAction(UIAlertAction(title: .localized("Cancel"), style: .cancel) { _ in
				continuation.resume(returning: false)
			})
			alert.addAction(UIAlertAction(title: .localized("Revoke and Continue"), style: .destructive) { _ in
				continuation.resume(returning: true)
			})
			guard let presenter = UIApplication.topViewController() else {
				continuation.resume(returning: false)
				return
			}
			presenter.present(alert, animated: true)
		}
	}
}

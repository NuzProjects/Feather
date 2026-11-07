//
//  InstallPreview.swift
//  Feather
//
//  Created by samara on 22.04.2025.
//

import SwiftUI
import NimbleViews
import NimbleExtensions
import IDeviceSwift
import OSLog
import SafariServices

// MARK: - View
struct InstallPreviewView: View {
	@Environment(\.dismiss) var dismiss

	@AppStorage("Feather.useShareSheetForArchiving") private var _useShareSheet: Bool = false
	@AppStorage("Feather.installationMethod") private var _installationMethod: Int = 0
	@AppStorage("Feather.serverMethod") private var _serverMethod: Int = 1
	@State private var _isWebviewPresenting = false
	@State private var progressTask: Task<Void, Never>?
	@State private var _safari: SFSafariViewController?
	
	var app: AppInfoPresentable
	@StateObject var viewModel: InstallerStatusViewModel
	@StateObject var installer: ServerInstaller
	
	@State var isSharing: Bool
	let inBackground: Bool
	let onClose: (() -> Void)?
	let onProgress: ((String, Double) -> Void)?

	init(app: AppInfoPresentable, isSharing: Bool = false, inBackground: Bool = false, onClose: (() -> Void)? = nil, onProgress: ((String, Double) -> Void)? = nil) {
		self.app = app
		self.isSharing = isSharing
		self.inBackground = inBackground
		self.onClose = onClose
		self.onProgress = onProgress
		let viewModel = InstallerStatusViewModel(isIdevice: UserDefaults.standard.integer(forKey: "Feather.installationMethod") == 1)
		self._viewModel = StateObject(wrappedValue: viewModel)
		self._installer = StateObject(wrappedValue: ServerInstaller(app: app, viewModel: viewModel))
	}
	
	// MARK: Body
	var body: some View {
		_content()
		.sheet(isPresented: $_isWebviewPresenting) {
			SafariRepresentableView(url: installer.pageEndpoint).ignoresSafeArea()
		}
		.onReceive(viewModel.$status) { newStatus in
			if _installationMethod == 0 {
				if case .ready = newStatus {
					if _serverMethod == 0 {
						let link = installer.iTunesLink
						UIApplication.shared.open(URL(string: link)!) { opened in
							DevLog.shared.log(opened ? .info : .error, "Fully Local install link \(opened ? "opened" : "failed to open"): \(link)", category: "Install")
						}
						DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
							guard case .ready = viewModel.status else { return }
							DevLog.shared.log(.warning, "iOS didn't request the install manifest from \(installer.plistEndpoint.absoluteString)", category: "Install")
							_offerSemiLocal(String.localized("iOS didn't start the install from Feather's local server."))
						}
					} else if _serverMethod == 1 {
						if inBackground {
							_presentSafari()
						} else {
							_isWebviewPresenting = true
						}
					}
				}
				
				if case .sendingPayload = newStatus, _serverMethod == 1 {
					_isWebviewPresenting = false
					_dismissSafari()
				}
				
				if case .installing = newStatus {
					if app.identifier == Bundle.main.bundleIdentifier {
						DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
							UIApplication.shared.suspend()
						}
					}
					if progressTask == nil {
						progressTask = startInstallProgressPolling(
							bundleID: app.identifier ?? "",
							viewModel: viewModel
						)
					}
				}
				
				switch newStatus {
				case .completed, .broken(_):
					progressTask?.cancel()
					progressTask = nil
					_dismissSafari()
					#if !targetEnvironment(macCatalyst)
					BackgroundAudioManager.shared.stop()
					#endif
					if inBackground {
						let failed: Bool = { if case .broken = newStatus { return true }; return false }()
						DispatchQueue.main.asyncAfter(deadline: .now() + (failed ? 4 : 1.5)) { _close() }
					}
				default:
					break
				}
			}
		}
		.onReceive(viewModel.objectWillChange) { _ in
			guard let onProgress else { return }
			DispatchQueue.main.async { onProgress(viewModel.statusLabel, min(1, max(0, viewModel.overallProgress))) }
		}
		.onAppear(perform: _install)

		#if !targetEnvironment(macCatalyst)
		.onAppear {
			BackgroundAudioManager.shared.start()
		}
		#endif
		
		.onDisappear {
			progressTask?.cancel()
			progressTask = nil
			_dismissSafari()
			
			#if !targetEnvironment(macCatalyst)
			BackgroundAudioManager.shared.stop()
			#endif
		}
	}
	
	private func _close() {
		if let onClose { onClose() } else { dismiss() }
	}

	private func _presentSafari(attempt: Int = 0) {
		guard _safari == nil, case .ready = viewModel.status else { return }
		guard let top = UIApplication.topViewController(), !(top is UIAlertController), !top.isBeingPresented, !top.isBeingDismissed else {
			if attempt < 40 {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { _presentSafari(attempt: attempt + 1) }
			}
			return
		}
		let safari = SFSafariViewController(url: installer.pageEndpoint)
		safari.modalPresentationStyle = .pageSheet
		top.present(safari, animated: true)
		_safari = safari
	}

	private func _dismissSafari() {
		_safari?.dismiss(animated: true)
		_safari = nil
	}

	private func _offerSemiLocal(_ reason: String) {
		UIAlertController.showAlert(
			title: String.localized("Fully Local Couldn't Install"),
			message: reason + "\n\n" + String.localized("Switch the Server Type to Semi Local and install again?"),
			actions: [
				UIAlertAction(title: String.localized("Use Semi Local"), style: .default) { _ in
					_serverMethod = 1
					_close()
				},
				UIAlertAction(title: String.localized("Cancel"), style: .cancel) { _ in _close() }
			]
		)
	}

	@ViewBuilder
	private func _content() -> some View {
		if inBackground {
			Color.clear.frame(width: 1, height: 1).allowsHitTesting(false)
		} else {
			ZStack {
				InstallProgressView(app: app, viewModel: viewModel)
				_status()
				_button()
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
			.background(Color(UIColor.secondarySystemBackground))
			.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
			.padding()
		}
	}

	@ViewBuilder
	private func _status() -> some View {
		Label(viewModel.statusLabel, systemImage: viewModel.statusImage)
			.padding()
			.labelStyle(.titleAndIcon)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
			.animation(.smooth, value: viewModel.statusImage)
	}
	
	@ViewBuilder
	private func _button() -> some View {
		ZStack {
			if viewModel.isCompleted {
				Button {
					UIApplication.openApp(with: app.identifier ?? "")
				} label: {
					NBButton("Open", systemImage: "", style: .text)
				}
				.padding()
				.compatTransition()
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
		.animation(.easeInOut(duration: 0.3), value: viewModel.isCompleted)
	}
	
	private func _install() {
		Task.detached {
			do {
				let handler = await ArchiveHandler(app: app, viewModel: viewModel)
				try await handler.move()
				
				let packageUrl = try await handler.archive()
				
				if await !isSharing {
					if await _installationMethod == 0 {
						if await _serverMethod == 0, !ServerInstaller.isCertificateTrusted() {
							await MainActor.run {
								UIAlertController.showAlertWithOk(
									title: "SSL Certificate Expired",
									message: "Fully Local's SSL certificate has expired, so iOS won't install the app. Tap Update SSL Certificates in Settings → Installation → Server, or switch the Server Type to Semi Local.",
									action: { _close() }
								)
							}
							return
						}
						if await _serverMethod == 0 {
							let host = await installer.sni()
							let reachable = ServerInstaller.resolvesToThisDevice(host)
							DevLog.shared.log(reachable ? .info : .warning, "Fully Local address \(host) \(reachable ? "resolves to this device" : "doesn't resolve to this device")", category: "Install")
							if !reachable {
								await MainActor.run { _offerSemiLocal(String.localized("Your network or DNS is blocking the address Fully Local uses, so iOS can't reach Feather's install server.")) }
								return
							}
						}
						try await MainActor.run {
							if let startError = installer.startError { throw startError }
							installer.packageUrl = packageUrl
							viewModel.status = .ready
						}
						
						if case .installing = await viewModel.status {
							let task = await startInstallProgressPolling(
								bundleID: app.identifier ?? "",
								viewModel: viewModel
							)

							await MainActor.run {
								progressTask = task
							}
						}
					} else if await _installationMethod == 1 {
						let handler = await InstallationProxy(viewModel: viewModel)
						try await handler.install(at: packageUrl, suspend: app.identifier == Bundle.main.bundleIdentifier!)
					}
				} else {
					let package = try await handler.moveToArchive(packageUrl, shouldOpen: !_useShareSheet)
					
					if await !_useShareSheet {
						await MainActor.run {
							dismiss()
						}
					} else {
						if let package {
							await MainActor.run {
								dismiss()
								UIActivityViewController.show(activityItems: [package])
							}
						}
					}
				}
			} catch {
				await progressTask?.cancel()
				DevLog.shared.error(error, while: "Installing app", category: "Install")
				
				await MainActor.run {
					UIAlertController.showAlertWithOk(
						title: .localized("Install"),
						message: (error as? LocalizedError)?.errorDescription ?? String(describing: error),
						action: {
							HeartbeatManager.shared.start(true)
							_close()
						}
					)
				}
			}
		}
	}
	
	private func startInstallProgressPolling(
		bundleID: String,
		viewModel: InstallerStatusViewModel
	) -> Task<Void, Never> {

		Task.detached(priority: .background) {
			var hasStarted = false

			while !Task.isCancelled {
				let rawProgress = await UIApplication.installProgress(for: bundleID) ?? 0.0

				if rawProgress > 0 {
					hasStarted = true
				}

				let progress = await hasStarted
					? _normalizeInstallProgress(rawProgress)
					: 0.0

				Logger.misc.info("Install progress for \(bundleID): \(progress)")

				await MainActor.run {
					viewModel.installProgress = progress
				}

				if hasStarted && rawProgress == 0 {
					await MainActor.run {
						viewModel.installProgress = 1.0
						viewModel.status = .completed(.success(()))
					}
					break
				}

				try? await Task.sleep(nanoseconds: 250_000_000)
			}
		}
	}

	private func _normalizeInstallProgress(_ rawProgress: Double) -> Double {
		min(1.0, max(0.0, (rawProgress - 0.6) / 0.3))
	}
}

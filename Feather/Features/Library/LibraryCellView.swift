import SwiftUI
import NimbleExtensions
import NimbleViews

struct LibraryCellView: View {
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@Environment(\.editMode) private var editMode
	@AppStorage("Feather.userTintColor") private var _tintHex: String = "#848ef9"
	@ObservedObject private var github = GitHubReleases.shared
	@ObservedObject private var updateManager = UpdateManager.shared
	@State private var _signedUpdateConfirmation: AppUpdate?
	@State private var _isSignedUpdateConfirmationPresented = false
	@State private var _installProblem: InstallProblem?

	var certInfo: Date.ExpirationInfo? {
		Storage.shared.getCertificate(from: app)?.expiration?.expirationInfo()
	}

	var certRevoked: Bool {
		Storage.shared.getCertificate(from: app)?.revoked == true
	}

	var app: AppInfoPresentable
	@Binding var selectedInfoAppPresenting: AnyApp?
	@Binding var selectedSigningAppPresenting: AnyApp?
	@Binding var selectedInstallAppPresenting: AnyApp?
	@Binding var selectedAppUUIDs: Set<String>

	private var _isSelected: Bool {
		guard let uuid = app.uuid else { return false }
		return selectedAppUUIDs.contains(uuid)
	}

	private func _toggleSelection() {
		guard let uuid = app.uuid else { return }
		if selectedAppUUIDs.contains(uuid) {
			selectedAppUUIDs.remove(uuid)
		} else {
			selectedAppUUIDs.insert(uuid)
		}
	}

	var body: some View {
		let isRegular = horizontalSizeClass != .compact
		let isEditing = editMode?.wrappedValue == .active

		HStack(spacing: 18) {
			if isEditing {
				Button {
					_toggleSelection()
				} label: {
					Image(systemName: _isSelected ? "checkmark.circle.fill" : "circle")
						.foregroundColor(_isSelected ? .accentColor : .secondary)
						.font(.title2)
				}
				.buttonStyle(.borderless)
			}

			_appIcon(for: app)

			NBTitleWithSubtitleView(
				title: app.name ?? .localized("Unknown"),
				subtitle: _desc,
				linelimit: 0
			)

			if github.busy.contains(app.uuid ?? "") { ProgressView().accessibilityLabel("Updating app") }
			if !isEditing {
				_buttonActions(for: app)
			}
		}
		.padding(isRegular ? 12 : 0)
		.background(
			isRegular
				? RoundedRectangle(cornerRadius: 18, style: .continuous)
				.fill(_isSelected && isEditing ? Color.accentColor.opacity(0.1) : Color(.quaternarySystemFill))
				: nil
		)
		.contentShape(Rectangle())
		.onTapGesture {
			if isEditing {
				_toggleSelection()
			}
		}
		.swipeActions(edge: .trailing, allowsFullSwipe: true) {
			if !isEditing {
				_actions(for: app)
				Button(.localized("Get Info"), systemImage: "info.circle") {
					selectedInfoAppPresenting = AnyApp(base: app)
				}
				.tint(.gray)
				if let uuid = app.uuid, github.updates[uuid] != nil {
					Button("Update", systemImage: "arrow.down.circle") { github.update(app) }.tint(Color(hex: _tintHex)).disabled(github.busy.contains(uuid))
				}
			}
		}
		.swipeActions(edge: .leading, allowsFullSwipe: true) {
			if !isEditing {
				if app.isSigned {
					Button(.localized("Install"), systemImage: "square.and.arrow.down") {
						_requestInstall(app)
					}
					.tint(Color(hex: _tintHex))
					Button(.localized("Re-sign"), systemImage: "signature") {
						ReplacementCoordinator.shared.requestSigning(app) { selectedSigningAppPresenting = $0 }
					}
					.tint(Color(hex: _tintHex))
					Button(.localized("Export"), systemImage: "square.and.arrow.up") {
						selectedInstallAppPresenting = AnyApp(base: app, archive: true)
					}
					.tint(Color(hex: _tintHex))
				} else {
					Button(.localized("Sign"), systemImage: "signature") {
						ReplacementCoordinator.shared.requestSigning(app) { selectedSigningAppPresenting = $0 }
					}
					.tint(Color(hex: _tintHex))
					Button(.localized("Install"), systemImage: "square.and.arrow.down") {
						_requestInstall(app)
					}
					.tint(Color(hex: _tintHex))
				}
			}
		}
		.contextMenu {
			if !isEditing {
				_contextActions(for: app)
				Divider()
				_contextActionsExtra(for: app)
				Divider()
				_actions(for: app)
			}
		}
		.alert(item: $_installProblem) { problem in
			Alert(
				title: Text(problem.title),
				message: Text(problem.message),
				primaryButton: .default(Text(.localized("Re-sign"))) {
					ReplacementCoordinator.shared.requestSigning(app) { selectedSigningAppPresenting = $0 }
				},
				secondaryButton: .destructive(Text(.localized("Install Anyway"))) {
					selectedInstallAppPresenting = AnyApp(base: app)
				}
			)
		}
		.confirmationDialog(
			.localized("Update Available"),
			isPresented: $_isSignedUpdateConfirmationPresented,
			titleVisibility: .visible
		) {
			Button(.localized("Install Current Version"), systemImage: "square.and.arrow.down") {
				_requestInstall(app)
			}
			if let update = _signedUpdateConfirmation {
				Button(.localized("Download Update"), systemImage: "arrow.down.circle") {
					_startUpdateDownload(update)
				}
			}
			Button(.localized("Cancel"), role: .cancel) {}
		} message: {
			if let update = _signedUpdateConfirmation {
				Text(verbatim: "\(update.appName) \(update.remoteVersion)")
			}
		}
	}

	private var _desc: String {
		if let version = app.version, let id = app.identifier {
			return "\(version) • \(id)"
		} else {
			return .localized("Unknown")
		}
	}
}

extension LibraryCellView {
	private func _appIcon(for app: AppInfoPresentable) -> some View {
		FRAppIconView(app: app, size: 57)
			.overlay(alignment: .topTrailing) {
				if updateManager.update(for: app) != nil || github.updates[app.uuid ?? ""] != nil {
					Image(systemName: "arrow.down.circle.fill")
						.font(.system(size: 18, weight: .semibold))
						.symbolRenderingMode(.palette)
						.foregroundStyle(.white, Color.accentColor)
						.background(
							Circle()
								.fill(Color(.systemBackground))
								.frame(width: 20, height: 20)
						)
						.offset(x: 5, y: -5)
						.accessibilityLabel(.localized("Update Available"))
				}
			}
	}

	@ViewBuilder
	private func _actions(for app: AppInfoPresentable) -> some View {
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteApp(for: app)
		}
	}

	@ViewBuilder
	private func _contextActions(for app: AppInfoPresentable) -> some View {
		Button(.localized("Get Info"), systemImage: "info.circle") {
			selectedInfoAppPresenting = AnyApp(base: app)
		}
	}

	@ViewBuilder
	private func _contextActionsExtra(for app: AppInfoPresentable) -> some View {
		if let uuid = app.uuid, github.updates[uuid] != nil { Button("Update", systemImage: "arrow.down.circle") { github.update(app) }.disabled(github.busy.contains(uuid)) }
		if let update = updateManager.update(for: app) {
			Button(.localized("Update"), systemImage: "arrow.down.circle") {
				if app.isSigned {
					_signedUpdateConfirmation = update
					_isSignedUpdateConfirmationPresented = true
				} else {
					_startUpdateDownload(update)
				}
			}
		}

		if app.isSigned {
			if let id = app.identifier {
				Button(.localized("Open"), systemImage: "app.badge.checkmark") {
					UIApplication.openApp(with: id)
				}
			}
			Button(.localized("Install"), systemImage: "square.and.arrow.down") {
				_requestInstall(app)
			}
			Button(.localized("Re-sign"), systemImage: "signature") {
				ReplacementCoordinator.shared.requestSigning(app) { selectedSigningAppPresenting = $0 }
			}
			Button(.localized("Export"), systemImage: "square.and.arrow.up") {
				selectedInstallAppPresenting = AnyApp(base: app, archive: true)
			}
		} else {
			Button(.localized("Install"), systemImage: "square.and.arrow.down") {
				_requestInstall(app)
			}
			Button(.localized("Sign"), systemImage: "signature") {
				ReplacementCoordinator.shared.requestSigning(app) { selectedSigningAppPresenting = $0 }
			}
		}
	}

	@ViewBuilder
	private func _buttonActions(for app: AppInfoPresentable) -> some View {
		Group {
			if let update = updateManager.update(for: app) {
				if app.isSigned {
					Button {
						_signedUpdateConfirmation = update
						_isSignedUpdateConfirmationPresented = true
					} label: {
						FRExpirationPillView(
							title: .localized("Install"),
							revoked: certRevoked,
							expiration: certInfo
						)
					}
				} else {
					Button {
						_startUpdateDownload(update)
					} label: {
						FRExpirationPillView(
							title: .localized("Update"),
							revoked: false,
							expiration: nil
						)
					}
				}
			} else if app.isSigned {
				Button {
					_requestInstall(app)
				} label: {
					FRExpirationPillView(
						title: .localized("Install"),
						revoked: certRevoked,
						expiration: certInfo
					)
				}
			} else {
				Button {
					ReplacementCoordinator.shared.requestSigning(app) { selectedSigningAppPresenting = $0 }
				} label: {
					FRExpirationPillView(
						title: .localized("Sign"),
						revoked: false,
						expiration: nil
					)
				}
			}
		}
		.buttonStyle(.borderless)
	}

	private func _startUpdateDownload(_ update: AppUpdate) {
		_ = DownloadManager.shared.startDownload(
			from: update.downloadURL,
			id: "FeatherManualDownload_Update_\(update.localUUID)",
			sourceProvenance: update.sourceProvenance
		)
	}
}

extension LibraryCellView {
	struct InstallProblem: Identifiable {
		let title: String
		let message: String
		var id: String { title }
	}

	private func _requestInstall(_ app: AppInfoPresentable) {
		guard app.isSigned, let problem = _problem(for: app) else {
			selectedInstallAppPresenting = AnyApp(base: app)
			return
		}
		UINotificationFeedbackGenerator().notificationOccurred(.warning)
		_installProblem = problem
	}

	private func _problem(for app: AppInfoPresentable) -> InstallProblem? {
		guard let certificate = Storage.shared.getCertificate(from: app) else { return nil }
		if certificate.revoked {
			return InstallProblem(
				title: .localized("Certificate Revoked"),
				message: .localized("This app was signed with a certificate that has been revoked, so iOS won't open it. Re-sign it with a valid certificate first.")
			)
		}
		if let expiration = certificate.expiration, expiration < Date() {
			return InstallProblem(
				title: .localized("Certificate Expired"),
				message: .localized("This app was signed with a certificate that has expired, so iOS won't open it. Re-sign it with a valid certificate first.")
			)
		}
		return nil
	}
}

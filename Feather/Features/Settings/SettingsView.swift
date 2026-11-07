import SwiftUI
import NimbleViews
import UIKit
import Darwin
import IDeviceSwift

struct SettingsView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	@State private var _isGetCertificatePresenting = false
	@State private var _widgetsNeedReinstall = false
	@ObservedObject private var _updater = FeatherUpdater.shared
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>

	private var selectedCertificate: CertificatePair? {
		guard
			_storedSelectedCert >= 0,
			_storedSelectedCert < _certificates.count
		else {
			return nil
		}
		return _certificates[_storedSelectedCert]
	}

	var body: some View {
		NBNavigationView(.localized("Settings")) {
			Form {
				Section {
					NavigationLink(destination: UpdatesView()) {
						Label(.localized("Updates"), systemImage: "arrow.down.app")
					}
					if _widgetsNeedReinstall {
						Button {
							FeatherUpdater.shared.install()
						} label: {
							Label(.localized("Finish Setting Up Widgets"), systemImage: "square.grid.2x2")
						}
					}
				}

				NBSection(.localized("Certificates")) {
					if let cert = selectedCertificate {
						NavigationLink(destination: CertificateOverviewDetailView(cert: cert)) {
							CertificatesCellView(cert: cert)
						}
					} else if _certificates.isEmpty {
						Button {
							_isGetCertificatePresenting = true
						} label: {
							HStack {
								Label {
									Text("Get a Certificate")
										.foregroundStyle(.primary)
								} icon: {
									Image(systemName: "plus.circle")
										.foregroundStyle(.tint)
								}
								Spacer()
								Image(systemName: "chevron.right")
									.font(.footnote.weight(.semibold))
									.foregroundStyle(.tertiary)
							}
						}
					}
					NavigationLink(destination: CertificatesView()) {
						Label(.localized("Certificates"), systemImage: "checkmark.seal")
					}
				} footer: {
					Text(.localized("Add and manage certificates used for signing applications."))
				}

				NBSection(.localized("Features")) {
					NavigationLink(destination: AppearanceView()) {
						Label(.localized("Appearance"), systemImage: "paintbrush")
					}
					NavigationLink(destination: ConfigurationView()) {
						Label(.localized("Signing Options"), systemImage: "signature")
					}
					NavigationLink(destination: InstallationView()) {
						Label(.localized("Installation"), systemImage: "arrow.down.circle")
					}
					NavigationLink(destination: DataTransferView()) {
						Label(.localized("Backup & Transfer"), systemImage: "externaldrive")
					}
				} footer: {
					Text(.localized("Configure the apps way of installing, its zip compression levels, and custom modifications to apps."))
				}

				_directories()

				NBSection(.localized("GitHub")) {
					Button { UIApplication.open("https://github.com/NuzProjects/Feather") } label: {
						Label { Text("Star on GitHub") } icon: { Image("GitHubMark").renderingMode(.template) }
					}
					Button("Report an Issue", systemImage: "exclamationmark.bubble") {
						UIApplication.open("https://github.com/NuzProjects/Feather/issues/new/choose")
					}
					NavigationLink(destination: AboutView()) {
						Label(.localized("About"), systemImage: "info.circle")
					}
				} footer: {
					Text("Feather is free and open source. A star helps other people find it.")
				}

				Section {
					NavigationLink(destination: ResetView()) {
						Label(.localized("Reset"), systemImage: "trash")
					}
				} footer: {
					Text(.localized("Reset the applications sources, certificates, apps, and general contents."))
				}
				.symbolVariant(.fill)
			}
			.nbReadableWidth()
			.onAppear {
				_repairSelectedCertificate()
				CertificateExpiry.refresh()
				_widgetsNeedReinstall = ExtensionHealth.state == .needsReinstall
			}
			.onChange(of: _certificates.count) { _ in _repairSelectedCertificate() }
			.onChange(of: _storedSelectedCert) { _ in CertificateExpiry.refresh() }
			.navigationDestination(isPresented: $_updater.openUpdatesPage) { UpdatesView() }
			.sheet(isPresented: $_isGetCertificatePresenting) {
				GetCertificateView()
					.presentationDetents([.medium, .large])
					.presentationDragIndicator(.visible)
			}
		}
	}
}

extension SettingsView {
	private func _repairSelectedCertificate() {
		guard !_certificates.isEmpty, !_certificates.indices.contains(_storedSelectedCert) else { return }
		_storedSelectedCert = 0
	}

	@ViewBuilder
	private func _directories() -> some View {
		NBSection(.localized("Misc")) {
			Button(.localized("Open Documents"), systemImage: "folder") {
				UIApplication.open(URL.documentsDirectory.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Archives"), systemImage: "folder") {
				UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Certificates"), systemImage: "folder") {
				UIApplication.open(FileManager.default.certificates.toSharedDocumentsURL()!)
			}
			NavigationLink(destination: DeveloperLogsView()) {
				Label("Developer Logs", systemImage: "ladybug")
			}
		} footer: {
			Text(String.localized("All of the apps files are contained in the documents directory, here are some quick links to these.") + " " + String.localized("Developer Logs has crash reports and errors you can export for bug reports."))
		}
	}
}

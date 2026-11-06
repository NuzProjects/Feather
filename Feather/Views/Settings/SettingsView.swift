//
//  SettingsView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit
import Darwin
import IDeviceSwift

// MARK: - View
struct SettingsView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	@State private var _currentIcon: String? = UIApplication.shared.alternateIconName
	@State private var _isGetCertificatePresenting = false
	@ObservedObject private var _updater = FeatherUpdater.shared
	// MARK: Fetch
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

    
    
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Settings")) {
			Form {
				Section {
					NavigationLink(destination: UpdatesView()) {
						Label("Updates", systemImage: "arrow.down.app")
					}				}

				Section {
					NavigationLink(destination: AppearanceView()) {
						Label(.localized("Appearance"), systemImage: "paintbrush")
					}
					NavigationLink(destination: AppIconView(currentIcon: $_currentIcon)) {
						Label(.localized("App Icon"), systemImage: "app.badge")
					}
					NavigationLink(destination: NavigatorView()) { Label("Navigator", systemImage: "dock.rectangle") }
				}
                
				NBSection(.localized("Certificates")) {
                    
					if let cert = selectedCertificate {
						NavigationLink(destination: CertificateOverviewDetailView(cert: cert)) {
							CertificatesCellView(cert: cert)
						}
					} else if _certificates.isEmpty {
						// Only when there are no certificates at all; looks like the other Settings rows.
						Button {
							_isGetCertificatePresenting = true
						} label: {
							HStack {
								Label {
									Text("Get a Certificate")
										.foregroundStyle(.primary)
								} icon: {
									Image(systemName: "seal")
										.foregroundStyle(Color.accentColor)
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
					NavigationLink(destination: ConfigurationView()) {
						Label(.localized("Signing Options"), systemImage: "signature")
					}
					NavigationLink(destination: ArchiveView()) {
						Label(.localized("Archive & Compression"), systemImage: "archivebox")
					}
					NavigationLink(destination: InstallationView()) {
						Label(.localized("Installation"), systemImage: "arrow.down.circle")
					}
					NavigationLink(destination: DataTransferView()) {
						Label("Backup & Transfer", systemImage: "externaldrive")
					}
				} footer: {
					Text(.localized("Configure the apps way of installing, its zip compression levels, and custom modifications to apps."))
				}
                
				_directories()

				NBSection("GitHub") {
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
			.onAppear {
				_repairSelectedCertificate()
				CertificateExpiry.refresh()
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

// MARK: - View extension
extension SettingsView {
	/// If the saved selection points past the list (for example after deleting a certificate),
	/// select the newest one so Settings and signing both use a real certificate.
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
			Text(String.localized("All of the apps files are contained in the documents directory, here are some quick links to these.") + " Developer Logs has crash reports and errors you can export for bug reports.")
		}
	}
}

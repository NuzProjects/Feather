import SwiftUI
import NimbleViews

// MARK: - View
struct CertificatesOverviewView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	@State private var _decoded: [String: Certificate] = [:]
	@State private var _isAddingPresenting = false

	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>

	private var _selected: CertificatePair? {
		_certificates.indices.contains(_storedSelectedCert) ? _certificates[_storedSelectedCert] : nil
	}

	// MARK: Body
	var body: some View {
		NBList("Certificate Overview") {
			if _certificates.isEmpty {
				Section {
					VStack(spacing: 10) {
						Image("Cert")
							.resizable()
							.scaledToFit()
							.frame(width: 80, height: 80)
						Text("No Certificates")
							.font(.headline)
						Text("Import a certificate to see when it expires, what it can do and which apps use it.")
							.font(.subheadline)
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.center)
						Button("Import Certificate") { _isAddingPresenting = true }
							.buttonStyle(.borderedProminent)
							.padding(.top, 4)
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, 12)
				}
			} else {
				Section {
					_summaryGrid()
				}
				.listRowBackground(Color.clear)
				.listRowInsets(EdgeInsets())

				if let selected = _selected {
					NBSection("In Use") {
						NavigationLink(destination: CertificateOverviewDetailView(cert: selected)) {
							_heroCard(for: selected)
						}
					} footer: {
						Text("Feather signs apps with this certificate.")
					}
				}

				NBSection("All Certificates", secondary: "\(_certificates.count)") {
					ForEach(Array(_certificates.enumerated()), id: \.element.uuid) { index, cert in
						NavigationLink(destination: CertificateOverviewDetailView(cert: cert)) {
							_row(for: cert, isSelected: index == _storedSelectedCert)
						}
					}
				}
			}
		}
		.onAppear(perform: _decodeAll)
		.onChange(of: _certificates.count) { _ in _decodeAll() }
		.refreshable {
			for cert in _certificates { Storage.shared.revokagedCertificate(for: cert) }
			_decodeAll()
		}
		.sheet(isPresented: $_isAddingPresenting) {
			CertificatesAddView()
				.presentationDetents([.medium])
		}
	}
}

// MARK: - Extension: View
extension CertificatesOverviewView {
	@ViewBuilder
	private func _summaryGrid() -> some View {
		let counts = Dictionary(grouping: _certificates, by: { CertificateStatus($0) }).mapValues(\.count)
		LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
			ForEach(CertificateStatus.allCases, id: \.self) { status in
				_tile(status: status, count: counts[status] ?? 0)
			}
		}
	}

	@ViewBuilder
	private func _tile(status: CertificateStatus, count: Int) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				Image(systemName: status.icon)
					.font(.system(size: 15, weight: .semibold))
					.foregroundStyle(.white)
					.frame(width: 30, height: 30)
					.background(Circle().fill(count == 0 ? Color.secondary.opacity(0.4) : status.color))
				Spacer()
				Text("\(count)")
					.font(.system(.title, design: .rounded).bold())
					.contentTransition(.numericText())
			}
			Text(status.title)
				.font(.subheadline.weight(.medium))
				.foregroundStyle(.secondary)
		}
		.padding(14)
		.background(
			RoundedRectangle(cornerRadius: CertificateOverviewStyle.cornerRadius, style: .continuous)
				.fill(Color(uiColor: .secondarySystemGroupedBackground))
		)
		.accessibilityElement(children: .combine)
	}

	@ViewBuilder
	private func _heroCard(for cert: CertificatePair) -> some View {
		let data = cert.uuid.flatMap { _decoded[$0] }
		VStack(alignment: .leading, spacing: 14) {
			HStack(spacing: 16) {
				CertificateValidityRing(expiration: cert.expiration, fraction: data?.remainingFraction() ?? 0)
				VStack(alignment: .leading, spacing: 4) {
					Text(cert.nickname ?? data?.Name ?? .localized("Unknown"))
						.font(.headline)
						.lineLimit(2)
					Text(data?.TeamName ?? "")
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.lineLimit(1)
					if let expiration = cert.expiration {
						Text("Expires \(expiration.formatted(date: .abbreviated, time: .shortened))")
							.font(.footnote)
							.foregroundStyle(.secondary)
					}
					CertificateStatusCapsule(status: CertificateStatus(cert))
						.padding(.top, 2)
				}
			}
			_pills(for: cert, data: data)
		}
		.padding(.vertical, 6)
	}

	@ViewBuilder
	private func _pills(for cert: CertificatePair, data: Certificate?) -> some View {
		let apps = cert.signedAppsList.count
		let items: [NBPillItem] = [
			NBPillItem(title: data?.deviceSummary ?? "—", icon: "iphone", color: .accentColor),
			NBPillItem(title: apps == 1 ? "1 app" : "\(apps) apps", icon: "app.badge", color: .accentColor),
			NBPillItem(title: data?.profileType ?? "—", icon: "doc.badge.gearshape", color: .accentColor)
		]
		HStack(spacing: 6) {
			ForEach(items.indices, id: \.self) { index in
				NBPillView(title: items[index].title, icon: items[index].icon, color: items[index].color, index: index, count: items.count)
			}
		}
	}

	@ViewBuilder
	private func _row(for cert: CertificatePair, isSelected: Bool) -> some View {
		let data = cert.uuid.flatMap { _decoded[$0] }
		let status = CertificateStatus(cert)
		HStack(spacing: 12) {
			CertificateValidityRing(expiration: cert.expiration, fraction: data?.remainingFraction() ?? 0, size: 40, showsLabel: false)
				.overlay {
					Image(systemName: status.icon)
						.font(.system(size: 13, weight: .semibold))
						.foregroundStyle(status.color)
				}
			VStack(alignment: .leading, spacing: 2) {
				HStack(spacing: 4) {
					Text(cert.nickname ?? data?.Name ?? .localized("Unknown"))
						.lineLimit(1)
					if isSelected {
						Image(systemName: "checkmark.circle.fill")
							.font(.caption)
							.foregroundStyle(Color.accentColor)
					}
				}
				Text(_subtitle(cert, data: data))
					.font(.footnote)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			Spacer(minLength: 8)
			Text(cert.revoked ? "Revoked" : cert.expiration?.expirationInfo().formatted ?? "")
				.font(.caption.bold())
				.foregroundStyle(status == .active ? Color.secondary : status.color)
		}
	}

	private func _subtitle(_ cert: CertificatePair, data: Certificate?) -> String {
		let apps = cert.signedAppsList.count
		return [data?.TeamName, apps == 1 ? "1 app" : "\(apps) apps"].compactMap { $0 }.joined(separator: " · ")
	}

	private func _decodeAll() {
		var result: [String: Certificate] = [:]
		for cert in _certificates {
			guard let uuid = cert.uuid else { continue }
			if let cached = _decoded[uuid] { result[uuid] = cached; continue }
			if let data = Storage.shared.getProvisionFileDecoded(for: cert) { result[uuid] = data }
		}
		withAnimation { _decoded = result }
	}
}

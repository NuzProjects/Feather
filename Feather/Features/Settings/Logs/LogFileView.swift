import SwiftUI
import NimbleViews

struct LogFileView: View {
	let url: URL
	let title: String
	var systemLog: URL? = nil

	private enum Source: String, CaseIterable { case feather = "Feather", system = "System" }
	private static let maxLines = 5000

	@State private var _source: Source = .feather
	@State private var _lines: [String] = []
	@State private var _isTruncated = false
	@State private var _search = ""
	@State private var _errorsOnly = false

	private var _visible: [(offset: Int, element: String)] {
		Array(_lines.enumerated()).filter { line in
			(!_errorsOnly || _severity(line.element) != nil)
			&& (_search.isEmpty || line.element.localizedCaseInsensitiveContains(_search))
		}
	}

	var body: some View {
		ScrollView {
			LazyVStack(alignment: .leading, spacing: 2) {
				if systemLog != nil {
					Picker("Source", selection: $_source) {
						ForEach(Source.allCases, id: \.self) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
					}
					.pickerStyle(.segmented)
					.padding(.bottom, 8)
				}
				if _isTruncated {
					Text("Showing the last \(Self.maxLines) lines. Export to see everything.")
						.font(.footnote)
						.foregroundStyle(.secondary)
						.padding(.bottom, 6)
				}
				if _visible.isEmpty {
					Text(LocalizedStringKey(_lines.isEmpty ? "This log is empty." : "No matching lines."))
						.foregroundStyle(.secondary)
						.frame(maxWidth: .infinity)
						.padding(.top, 40)
				}
				ForEach(_visible, id: \.offset) { line in
					Text(line.element)
						.font(.system(.caption, design: .monospaced))
						.foregroundStyle(_severity(line.element) ?? .primary)
						.frame(maxWidth: .infinity, alignment: .leading)
						.textSelection(.enabled)
				}
			}
			.padding()
		}
		.navigationTitle(title)
		.nbSoftTopEdge()
		.navigationBarTitleDisplayMode(.inline)
		.searchable(text: $_search, prompt: "Search log")
		.toolbar {
			ToolbarItemGroup(placement: .navigationBarTrailing) {
				Button {
					_errorsOnly.toggle()
				} label: {
					Image(systemName: _errorsOnly ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
				}
				.accessibilityLabel("Show errors only")
				Button {
					UIActivityViewController.show(activityItems: [_source == .system ? (systemLog ?? url) : url])
				} label: {
					Image(systemName: "square.and.arrow.up")
				}
				.accessibilityLabel("Share")
			}
		}
		.onAppear(perform: _load)
		.onChange(of: _source) { _ in _load() }
	}
}

extension LogFileView {
	private func _load() {
		let file = _source == .system ? (systemLog ?? url) : url
		let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
		var lines = text.components(separatedBy: "\n")
		if lines.last?.isEmpty == true { lines.removeLast() }
		_isTruncated = lines.count > Self.maxLines
		_lines = Array(lines.suffix(Self.maxLines))
	}

	private func _severity(_ line: String) -> Color? {
		if line.contains("[ERROR]") || line.contains("[FAULT]") || line.contains(CrashTrap.marker) || line.contains("\"exceptionType\"") { return .red }
		if line.contains("[WARN]") { return .orange }
		return nil
	}
}

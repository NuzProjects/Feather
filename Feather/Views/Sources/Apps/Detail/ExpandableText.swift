//
//  ExpandableText.swift
//  Feather
//
//  Created by samsam on 7/26/25.
//


import SwiftUI

struct ExpandableText: View {
	let text: String
	let lineLimit: Int

	@State private var expanded: Bool = false
	@State private var limitedHeight: CGFloat = 0
	@State private var fullHeight: CGFloat = 0

	/// True when the full text is taller than the collapsed text, measured in the text's own font.
	private var truncated: Bool { fullHeight > limitedHeight + 1 }

	/// Release notes are often Markdown: render bold, italics, code and links, turn headings into
	/// bold lines and list items into bullets, and fall back to plain text if it can't be parsed.
	private var _rendered: AttributedString {
		let lines = text.components(separatedBy: .newlines).map { line -> String in
			let trimmed = line.trimmingCharacters(in: .whitespaces)
			if trimmed.hasPrefix("#") {
				let heading = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
				return heading.isEmpty ? "" : "**\(heading)**"
			}
			if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("+ ") {
				return "• " + trimmed.dropFirst(2)
			}
			return line
		}
		let markdown = lines.joined(separator: "\n")
		return (try? AttributedString(
			markdown: markdown,
			options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)
		)) ?? AttributedString(text)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(_rendered)
				.lineLimit(expanded ? nil : lineLimit)
				.foregroundStyle(.primary)
				.contentTransition(.identity)
				.fixedSize(horizontal: false, vertical: true)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(alignment: .topLeading) {
					ZStack(alignment: .topLeading) {
						Text(_rendered)
							.lineLimit(lineLimit)
							.fixedSize(horizontal: false, vertical: true)
							.background(_HeightReader { limitedHeight = $0 })
						Text(_rendered)
							.fixedSize(horizontal: false, vertical: true)
							.background(_HeightReader { fullHeight = $0 })
					}
					.hidden()
					.allowsHitTesting(false)
				}
				.contentShape(Rectangle())
				.onTapGesture {
					guard truncated else { return }
					withAnimation(.easeInOut(duration: 0.25)) {
						expanded.toggle()
					}
				}

			if truncated {
				Button(action: {
					withAnimation(.easeInOut(duration: 0.25)) {
						expanded.toggle()
					}
				}) {
					Text(expanded ? .localized("Less") : .localized("More"))
						.font(.caption)
						.foregroundColor(.accentColor)
						.contentTransition(.identity)
				}
				.buttonStyle(.borderless)
			}
		}
	}
}

private struct _HeightReader: View {
	let onChange: (CGFloat) -> Void

	var body: some View {
		GeometryReader { proxy in
			Color.clear
				.onAppear { onChange(proxy.size.height) }
				.onChange(of: proxy.size.height) { onChange($0) }
		}
	}
}

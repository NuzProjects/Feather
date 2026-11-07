//
//  SigningOptionsView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import SwiftUI
import NimbleViews
import Zip

// MARK: - View
struct ConfigurationView: View {
	@StateObject private var _optionsManager = OptionsManager.shared
	@State var isRandomAlertPresenting = false
	@State var randomString = ""
	@AppStorage("Feather.compressionLevel") private var _compressionLevel: Int = ZipCompression.DefaultCompression.rawValue
	@AppStorage("Feather.useShareSheetForArchiving") private var _useShareSheet: Bool = false
	
	// MARK: Body
	var body: some View {
		NBList(.localized("Signing Options")) {
			Section {
				NavigationLink(destination: ConfigurationDictView(
					title: .localized("Display Names"),
					dataDict: $_optionsManager.options.displayNames
				)
				) {
					Label(.localized("Display Names"), systemImage: "character.cursor.ibeam")
				}
				NavigationLink(destination: ConfigurationDictView(
					title: .localized("Identifiers"),
					dataDict: $_optionsManager.options.identifiers
				)
				) {
					Label(.localized("Identifiers"), systemImage: "person.text.rectangle")
				}
			}footer: {
				Text(.localized("This allows you to set rules for automatically replacing the Bundle ID/Display Name when signing an app."))
			}
			SigningOptionsView(options: $_optionsManager.options)

			NBSection(.localized("Export")) {
				Picker(.localized("Compression Level"), systemImage: "archivebox", selection: $_compressionLevel) {
					ForEach(ZipCompression.allCases, id: \.rawValue) { level in
						Text(level.label).tag(level)
					}
				}
				Toggle(.localized("Show Sheet when Exporting"), systemImage: "square.and.arrow.up", isOn: $_useShareSheet)
			} footer: {
				Text(.localized("Toggling show sheet will present a share sheet after exporting to your files."))
			}
		}
		.toolbar {
			NBToolbarMenu(
				systemImage: "character.textbox",
				style: .icon,
				placement: .topBarTrailing
			) {
				_randomMenuItem()
			}
		}
		.alert(_optionsManager.options.ppqString, isPresented: $isRandomAlertPresenting) {
			_randomMenuAlert()
		}
		.onChange(of: _optionsManager.options) { _ in
			_optionsManager.saveOptions()
		}
	}
}

// MARK: - Extension: View
extension ConfigurationView {
	@ViewBuilder
	private func _randomMenuItem() -> some View {
		Section(_optionsManager.options.ppqString) {
			Button(.localized("Change")) {
				isRandomAlertPresenting = true
			}
			Button(.localized("Copy")) {
				UIPasteboard.general.string = _optionsManager.options.ppqString
			}
		}
	}
	
	@ViewBuilder
	private func _randomMenuAlert() -> some View {
		TextField(.localized("String"), text: $randomString)
		Button(.localized("Save")) {
			if !randomString.isEmpty {
				_optionsManager.options.ppqString = randomString
			}
		}
		
		Button(.localized("Cancel"), role: .cancel) {}
	}
}

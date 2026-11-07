import Foundation.NSString
import SwiftUI

extension String {
	static public func localized(_ name: String) -> String {
		NSLocalizedString(name, comment: "")
	}

	static public func localized(_ name: String, arguments: CVarArg...) -> String {
		String(format: NSLocalizedString(name, comment: ""), arguments: arguments)
	}
	public func localized() -> String {
		String.localized(self)
	}
}

extension LocalizedStringKey {
	static public func localized(_ key: String) -> LocalizedStringKey {
		LocalizedStringKey(key)
	}
}

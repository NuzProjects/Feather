import Foundation

extension Int64 {
	public var formattedByteCount: String {
		let formatter = ByteCountFormatter()
		formatter.allowedUnits = [.useAll]
		formatter.countStyle = .file
		return formatter.string(fromByteCount: self)
	}
}

import Foundation
import UIKit

enum AppCompatibility {
	enum Issue: Equatable {
		case encrypted
		case needsNewerIOS(String)

		var message: String {
			switch self {
			case .encrypted:
				return .localized("This app is still encrypted by the App Store, so it won't open after signing. Use a decrypted IPA instead.")
			case .needsNewerIOS(let minimum):
				return String(format: .localized("This app needs iOS %@ or later, but this device is on iOS %@, so it may not open."), minimum, UIDevice.current.systemVersion)
			}
		}
	}

	static func issues(for app: AppInfoPresentable) -> [Issue] {
		guard
			let bundle = Storage.shared.getAppDirectory(for: app),
			let info = NSDictionary(contentsOf: bundle.appendingPathComponent("Info.plist")) as? [String: Any]
		else { return [] }

		var result: [Issue] = []
		if let executable = info["CFBundleExecutable"] as? String, isEncrypted(bundle.appendingPathComponent(executable)) {
			result.append(.encrypted)
		}
		if let minimum = info["MinimumOSVersion"] as? String, isVersion(minimum, newerThan: UIDevice.current.systemVersion) {
			result.append(.needsNewerIOS(minimum))
		}
		return result
	}

	static func isVersion(_ version: String, newerThan other: String) -> Bool {
		let lhs = version.split(separator: ".").map { Int($0) ?? 0 }
		let rhs = other.split(separator: ".").map { Int($0) ?? 0 }
		for index in 0..<max(lhs.count, rhs.count) {
			let a = index < lhs.count ? lhs[index] : 0
			let b = index < rhs.count ? rhs[index] : 0
			if a != b { return a > b }
		}
		return false
	}

	static func isEncrypted(_ url: URL) -> Bool {
		guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
		defer { try? handle.close() }

		func read(_ offset: UInt64, _ count: Int) -> [UInt8]? {
			guard (try? handle.seek(toOffset: offset)) != nil, let data = try? handle.read(upToCount: count), data.count == count else { return nil }
			return [UInt8](data)
		}

		guard let head = read(0, 8) else { return false }
		let magic = _be32(head, 0)
		var slices: [UInt64] = [0]
		if magic == 0xCAFEBABE || magic == 0xCAFEBABF {
			let is64 = magic == 0xCAFEBABF
			let count = Int(_be32(head, 4))
			let entrySize = is64 ? 32 : 20
			guard count > 0, count < 32, let table = read(8, count * entrySize) else { return false }
			slices = (0..<count).map { index in
				let base = index * entrySize
				return is64 ? _be64(table, base + 8) : UInt64(_be32(table, base + 8))
			}
		}
		return slices.contains { _sliceIsEncrypted(read, at: $0) }
	}

	private static func _sliceIsEncrypted(_ read: (UInt64, Int) -> [UInt8]?, at offset: UInt64) -> Bool {
		guard let header = read(offset, 28) else { return false }
		let magic = _le32(header, 0)
		let headerSize: UInt64
		switch magic {
		case 0xFEEDFACF: headerSize = 32
		case 0xFEEDFACE: headerSize = 28
		default: return false
		}
		let commandCount = Int(_le32(header, 16))
		let commandsSize = Int(_le32(header, 20))
		guard commandsSize > 0, commandsSize < 4_000_000, let commands = read(offset + headerSize, commandsSize) else { return false }

		var position = 0
		for _ in 0..<commandCount {
			guard position + 20 <= commands.count else { break }
			let command = _le32(commands, position)
			let size = Int(_le32(commands, position + 4))
			if command == 0x21 || command == 0x2C, _le32(commands, position + 16) != 0 {
				return true
			}
			guard size > 0 else { break }
			position += size
		}
		return false
	}

	private static func _le32(_ bytes: [UInt8], _ i: Int) -> UInt32 {
		UInt32(bytes[i]) | UInt32(bytes[i + 1]) << 8 | UInt32(bytes[i + 2]) << 16 | UInt32(bytes[i + 3]) << 24
	}

	private static func _be32(_ bytes: [UInt8], _ i: Int) -> UInt32 {
		UInt32(bytes[i]) << 24 | UInt32(bytes[i + 1]) << 16 | UInt32(bytes[i + 2]) << 8 | UInt32(bytes[i + 3])
	}

	private static func _be64(_ bytes: [UInt8], _ i: Int) -> UInt64 {
		UInt64(_be32(bytes, i)) << 32 | UInt64(_be32(bytes, i + 4))
	}
}

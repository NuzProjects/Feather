//
//  SwiftAR.swift
//  SwiftAR
//
//  Created by nekohaxx on 8/18/24.
//

import Foundation

class AR: NSObject {
	private let _url: URL

	init(with url: URL) {
		self._url = url
		super.init()
	}

	/// Reads every member of an `ar` archive (the container format of `.deb` files).
	/// Malformed archives throw `ARError` instead of crashing.
	func extract() async throws -> [ARFileModel] {
		let data: Data
		do {
			data = try Data(contentsOf: _url, options: .mappedIfSafe)
		} catch {
			throw ARError.badArchive("Couldn't read \(_url.lastPathComponent)")
		}

		let magic: [UInt8] = [0x21, 0x3c, 0x61, 0x72, 0x63, 0x68, 0x3e, 0x0a] // "!<arch>\n"
		guard data.count >= magic.count, [UInt8](data.prefix(magic.count)) == magic else {
			throw ARError.badArchive("Invalid magic")
		}

		var offset = data.startIndex + magic.count
		var files: [ARFileModel] = []
		while offset < data.endIndex {
			// Some archives pad the end with a newline; stop when there isn't room for another header.
			guard data.endIndex - offset >= 60 else { break }
			let file = try _getFileInfo(data, offset)
			files.append(file)
			offset += 60 + file.size
			if file.size % 2 == 1 { offset += 1 }
		}
		return files
	}

	private func _getFileInfo(_ data: Data, _ offset: Int) throws -> ARFileModel {
		func field(_ start: Int, _ length: Int) -> String {
			let bytes = data.subdata(in: (offset + start)..<(offset + start + length))
			return String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespaces)
		}

		guard let size = Int(field(48, 10)), size >= 0 else {
			throw ARError.badArchive("Invalid size")
		}
		guard offset + 60 + size <= data.endIndex else {
			throw ARError.badArchive("Truncated archive")
		}

		// GNU ar ends names with "/". Keep only a plain file name so nothing is written outside the work folder.
		var name = field(0, 16)
		if name.hasSuffix("/") { name.removeLast() }
		name = (name as NSString).lastPathComponent
		guard !name.isEmpty, name != ".", name != ".." else {
			throw ARError.badArchive("Invalid name")
		}

		return ARFileModel(
			name: name,
			modificationDate: Date(timeIntervalSince1970: Double(field(16, 12)) ?? 0),
			ownerId: Int(field(28, 6)) ?? 0,
			groupId: Int(field(34, 6)) ?? 0,
			mode: Int(field(40, 8), radix: 8) ?? 0o644,
			size: size,
			content: data.subdata(in: (offset + 60)..<(offset + 60 + size))
		)
	}
}

enum ARError: LocalizedError {
	case badArchive(String)

	var errorDescription: String? {
		switch self {
		case .badArchive(let reason): return "This .deb file couldn't be read (\(reason))."
		}
	}
}

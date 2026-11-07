import XCTest
@testable import FeatherCore

final class TransferFilesTests: XCTestCase {
	func testMergeKeepsExistingFilesAndSource() throws {
		let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: root) }
		let source = root.appendingPathComponent("source")
		let target = root.appendingPathComponent("target")
		try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
		try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
		try Data("old".utf8).write(to: source.appendingPathComponent("same"))
		try Data("new".utf8).write(to: target.appendingPathComponent("same"))
		try Data("app".utf8).write(to: source.appendingPathComponent("added"))
		_ = try TransferFiles.merge(from: source, to: target)
		XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("same")), Data("new".utf8))
		XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("added")), Data("app".utf8))
		XCTAssertTrue(FileManager.default.fileExists(atPath: source.appendingPathComponent("added").path))
	}
	func testRejectsLinksOutsideBackupAndRollsBackCopies() throws {
		let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: root) }
		let source = root.appendingPathComponent("source")
		let target = root.appendingPathComponent("target")
		try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
		try Data("outside".utf8).write(to: root.appendingPathComponent("secret"))
		try FileManager.default.createSymbolicLink(at: source.appendingPathComponent("link"), withDestinationURL: root.appendingPathComponent("secret"))
		XCTAssertThrowsError(try TransferFiles.merge(from: source, to: target))
		XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
		XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("secret").path))
	}
}

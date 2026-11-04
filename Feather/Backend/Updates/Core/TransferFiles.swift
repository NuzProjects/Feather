import Foundation

enum TransferFileError: LocalizedError {
    case invalid
    var errorDescription: String? { "The backup folder contains an invalid path or unsupported symbolic link." }
}

enum TransferFiles {
    @discardableResult
    static func merge(from source: URL, to destination: URL) throws -> [URL] {
        let manager = FileManager.default
        var directory: ObjCBool = false
        guard manager.fileExists(atPath: source.path, isDirectory: &directory), directory.boolValue else { throw TransferFileError.invalid }
        var created: [URL] = []
        let root = source.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        func copy(_ from: URL, _ to: URL) throws {
            let values = try from.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let resolved = from.resolvingSymlinksInPath().standardizedFileURL.path
            guard resolved + "/" == root || resolved.hasPrefix(root) else { throw TransferFileError.invalid }
            if values.isSymbolicLink == true { throw TransferFileError.invalid }
            if values.isDirectory == true {
                if !manager.fileExists(atPath: to.path) { try manager.createDirectory(at: to, withIntermediateDirectories: true); created.append(to) }
                for child in try manager.contentsOfDirectory(at: from, includingPropertiesForKeys: nil) { try copy(child, to.appendingPathComponent(child.lastPathComponent)) }
            } else if !manager.fileExists(atPath: to.path) {
                try manager.copyItem(at: from, to: to); created.append(to)
            }
        }
        do { try copy(source, destination); return created }
        catch { for url in created.reversed() { try? manager.removeItem(at: url) }; throw error }
    }
}

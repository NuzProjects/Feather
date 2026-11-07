import Foundation.NSURL

extension URL {
	public func toSharedDocumentsURL() -> URL? {
		let urlString = self.absoluteString

		guard urlString.hasPrefix("file://") else {
			return nil
		}

		let newURLString = "shareddocuments://" + urlString.dropFirst("file://".count)
		return URL(string: newURLString)
	}
}

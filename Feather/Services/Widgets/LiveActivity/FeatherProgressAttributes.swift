#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
import Foundation

struct FeatherProgressAttributes: ActivityAttributes {
	struct ContentState: Codable, Hashable {
		var title: String
		var detail: String
		var fraction: Double
		var symbol: String
		var tint: String
		var others: Int
		var finished: Bool
	}
}
#endif

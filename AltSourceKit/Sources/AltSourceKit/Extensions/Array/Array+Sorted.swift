import Foundation

extension Array where Element: Comparable {
	func sorted<T: Comparable>(path keyPath: KeyPath<Element, T>) -> [Element] {
		self.sorted { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
	}
}

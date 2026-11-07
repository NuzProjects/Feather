extension Array {
	subscript(safe index: Int) -> Element? {
		if indices.contains(index) {
			return self[index]
		}
		return nil
	}
}

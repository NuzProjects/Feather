import SwiftUI
import WidgetKit

@main
struct FeatherWidgetsBundle: WidgetBundle {
	var body: some Widget {
		CertificateWidget()
		LibraryWidget()
		FeatherProgressActivityWidget()
	}
}

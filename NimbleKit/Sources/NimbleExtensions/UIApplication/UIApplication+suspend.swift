import UIKit.UIApplication

extension UIApplication {
	public func suspend() {
		CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
		self.perform(#selector(NSXPCConnection.suspend))
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			exit(0)
		}
	}
	public func suspendAndReopen() {
		suspend()
		UIApplication.openApp(with: Bundle.main.bundleIdentifier!)
	}
}

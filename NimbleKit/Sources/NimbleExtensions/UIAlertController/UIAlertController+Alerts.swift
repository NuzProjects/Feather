import UIKit.UIAlertController

extension UIAlertController {
	static public func showAlertWithCancel(
		_ presenter: UIViewController? = UIApplication.topViewController(),
		_ popoverFromView: UIView? = nil,
		title: String?,
		message: String?,
		style: UIAlertController.Style = .alert,
		actions: [UIAlertAction]
	) {
		var actions = actions
		actions.append(
			UIAlertAction(title: .localized("Cancel"), style: .cancel, handler: nil)
		)

		showAlert(
			presenter,
			popoverFromView,
			title: title,
			message: message,
			style: style,
			actions: actions
		)
	}
	static public func showAlertWithOk(
		_ presenter: UIViewController? = UIApplication.topViewController(),
		_ popoverFromView: UIView? = nil,
		title: String?,
		message: String?,
		style: UIAlertController.Style = .alert,
		isCancel: Bool = false,
		action: (() -> Void)? = nil
	) {
		var actions: [UIAlertAction] = []

		let alertAction = UIAlertAction(
			title: "OK",
			style: isCancel ? .cancel : .default,
			handler: { _ in
				if !isCancel {
					action?()
				}
			}
		)

		actions.append(alertAction)

		showAlert(
			presenter,
			popoverFromView,
			title: title,
			message: message,
			style: style,
			actions: actions
		)
	}
	static public func showAlertWithRestart(
		_ presenter: UIViewController? = UIApplication.topViewController(),
		_ popoverFromView: UIView? = nil,
		title: String?,
		message: String?,
		style: UIAlertController.Style = .alert
	) {
		var actions: [UIAlertAction] = []
		actions.append(
			UIAlertAction(title: "Suspend", style: .default) { _ in
				UIApplication.shared.suspend()
			}
		)
		actions.append(
			UIAlertAction(title: "Later", style: .cancel, handler: nil)
		)

		showAlert(
			presenter,
			popoverFromView,
			title: title,
			message: message,
			style: style,
			actions: actions
		)
	}
	static public func showAlert(
		_ presenter: UIViewController? = UIApplication.topViewController(),
		_ popoverFromView: UIView? = nil,
		title: String?,
		message: String?,
		style: UIAlertController.Style = .alert,
		actions: [UIAlertAction]
	) {
		let alert = Self(title: title, message: message, preferredStyle: style)
		actions.forEach { alert.addAction($0) }

		if
			style == .actionSheet,
			let popover = alert.popoverPresentationController,
			let view = popoverFromView
		{
			popover.sourceView = view
			popover.sourceRect = view.bounds
			popover.permittedArrowDirections = .any
		}

		guard let presenter else { return }
		presenter.present(alert, animated: true)
	}
}

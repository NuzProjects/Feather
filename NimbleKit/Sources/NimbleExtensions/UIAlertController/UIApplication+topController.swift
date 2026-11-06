//
//  UIApplication+topController.swift
//  Loader
//
//  Created by samara on 18.03.2025.
//

import UIKit

extension UIApplication {
	public static var _rootViewController: UIViewController? {
		if let root = UIApplication.shared.keyWindow?.rootViewController { return root }
		let windows = UIApplication.shared.connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.sorted { ($0.activationState == .foregroundActive ? 0 : 1) < ($1.activationState == .foregroundActive ? 0 : 1) }
			.flatMap { $0.windows }
		return (windows.first(where: { $0.isKeyWindow }) ?? windows.first)?.rootViewController
	}

	/// This belongs to https://stackoverflow.com/a/30858591
	public class func topViewController(controller: UIViewController? = UIApplication._rootViewController) -> UIViewController? {
		if let navigationController = controller as? UINavigationController {
			return topViewController(controller: navigationController.visibleViewController)
		}
		if let tabController = controller as? UITabBarController {
			if let selected = tabController.selectedViewController {
				return topViewController(controller: selected)
			}
		}
		if let presented = controller?.presentedViewController {
			return topViewController(controller: presented)
		}
		return controller
	}
}

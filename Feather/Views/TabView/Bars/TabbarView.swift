//
//  TabbarView.swift
//  feather
//
//  Created by samara on 23.03.2025.
//

import SwiftUI

struct TabbarView: View {
	@ObservedObject private var navigator = NavigatorPreferences.shared
	@State private var selectedTab: TabEnum = .sources

	var body: some View {
		TabView(selection: $selectedTab) {
			ForEach(navigator.tabs, id: \.hashValue) { tab in
				TabEnum.view(for: tab)
					.tabItem {
						if navigator.showLabels { Label(tab.title, systemImage: tab.icon) } else { Image(systemName: tab.icon).accessibilityLabel(tab.title) }
					}
					.tag(tab)
			}
		}
		.onChange(of: navigator.tabs) { tabs in
			if !tabs.contains(selectedTab) { selectedTab = .settings }
		}
	}
}

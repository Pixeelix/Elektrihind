//
//  TabBarView.swift
//  NordPrice
//
//  Created by Martin Pihooja on 11.12.2021.
//

import SwiftUI
import UIKit

struct TabBarView: View {
    @Binding var selection: Int
    @EnvironmentObject var settings: AppSettings
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Full-screen iPad: today and tomorrow share one dashboard tab. Split View
    /// and phones keep the separate tabs.
    private var usesDashboard: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    /// The dashboard has no tomorrow tab, so a request for it (e.g. from a price
    /// notification) shows the dashboard, which contains tomorrow's prices.
    private var tabSelection: Binding<Int> {
        Binding(
            get: { usesDashboard && selection == 1 ? 0 : selection },
            set: { selection = $0 }
        )
    }
    
    /// Selected tab uses the website's brand blue in both light and dark mode.
    private var selectedTintColor: UIColor {
        UIColor(red: 0x7B/255, green: 0x8F/255, blue: 0xFF/255, alpha: 1)
    }
    
    private func setTabBarTransparentAppearance() {
        if #available(iOS 26.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            func configure(_ itemAppearance: UITabBarItemAppearance) {
                itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.label]
            }
            configure(appearance.stackedLayoutAppearance)
            configure(appearance.inlineLayoutAppearance)
            configure(appearance.compactInlineLayoutAppearance)
        }
    }
    
    var body: some View {
        Group {
            TabView(selection: tabSelection) {
                if usesDashboard {
                    DashboardView()
                        .tag(0)
                        .tabItem {
                            Image(systemName: "bolt.fill").symbolRenderingMode(.monochrome)
                            Text(settings.localizedString("LABEL_PRICES"))
                        }
                        .background(Color.backgroundColor.edgesIgnoringSafeArea(.all))
                } else {
                    TodayView()
                        .tag(0)
                        .tabItem {
                            Image(systemName: "bolt.fill").symbolRenderingMode(.monochrome)
                            Text(settings.localizedString("LABEL_TODAY"))
                        }
                        .background(Color.backgroundColor.edgesIgnoringSafeArea(.all))

                    TomorrowView()
                        .tag(1)
                        .tabItem {
                            Image(systemName: "clock.fill").symbolRenderingMode(.monochrome)
                            Text(settings.localizedString("LABEL_TOMORROW"))
                        }
                        .background(Color.backgroundColor.edgesIgnoringSafeArea(.all))
                }

                SettingsView()
                    .tag(2)
                    .tabItem {
                        Image(systemName: "gearshape.fill").symbolRenderingMode(.monochrome)
                        Text(settings.localizedString("LABEL_SETTINGS"))
                    }
                    .background(Color.backgroundColor.edgesIgnoringSafeArea(.all))
            }
            .tint(Color(selectedTintColor))
            .onAppear {
                UITabBar.appearance().tintColor = selectedTintColor
                UITabBar.appearance().unselectedItemTintColor = .secondaryLabel
            }
            .onChange(of: selection) { _ in
                UITabBar.appearance().tintColor = selectedTintColor
            }
            .hideTabBarBackground()
            .onAppear { setTabBarTransparentAppearance() }
        }
    }
}

private extension View {
    
    @ViewBuilder
    func hideTabBarBackground() -> some View {
        if #available(iOS 26.0, *) {
            self.toolbarBackground(.hidden, for: .tabBar)
        } else {
            self
        }
    }
}

struct TabBarView_Previews: PreviewProvider {
    static var previews: some View {
        TabBarView(selection: Binding.constant(0))
            .environmentObject(AppSettings())
            .previewLayout(.sizeThatFits)
    }
}

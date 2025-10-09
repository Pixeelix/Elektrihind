//
//  TabBarView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 11.12.2021.
//

import SwiftUI
import UIKit

struct TabBarView: View {
    @Binding var selection: Int
    @EnvironmentObject var shared: Globals
    
    private var selectedTintColor: UIColor {
        switch selection {
        case 0: return UIColor.orange
        case 1: return UIColor(red: 102/255, green: 212/255, blue: 207/255, alpha: 1)
        case 2: return UIColor(red: 172/255, green: 142/255, blue: 104/255, alpha: 1)
        default: return UIColor.systemBlue
        }
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
            TabView(selection: $selection) {
                TodayView(tabSelection: $selection)
                    .tag(0)
                    .tabItem {
                        Image(systemName: "bolt.fill").symbolRenderingMode(.monochrome)
                        Text(shared.localizedString("LABEL_TODAY"))
                    }
                    .background(Color.backgroundColor.edgesIgnoringSafeArea(.all))

                TomorrowView(tabSelection: $selection)
                    .tag(1)
                    .tabItem {
                        Image(systemName: "clock.fill").symbolRenderingMode(.monochrome)
                        Text(shared.localizedString("LABEL_TOMORROW"))
                    }
                    .background(Color.backgroundColor.edgesIgnoringSafeArea(.all))

                SettingsView()
                    .tag(2)
                    .tabItem {
                        Image(systemName: "gearshape.fill").symbolRenderingMode(.monochrome)
                        Text(shared.localizedString("LABEL_SETTINGS"))
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
            .environmentObject(Globals())
            .previewLayout(.sizeThatFits)
    }
}

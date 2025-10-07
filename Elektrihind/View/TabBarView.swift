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
    
    private var selectedTintColor: Color {
        switch selection {
        case 0:
            return .orange // Today
        case 1:
            return Color(red: 102/255.0, green: 212/255.0, blue: 207/255.0) // Tomorrow
        case 2:
            return Color(red: 172/255.0, green: 142/255.0, blue: 104/255.0) // Settings
        default:
            return .blue
        }
    }
    
    private func setTabBarTransparentAppearance() {
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
    
    var body: some View {
        Group {
            TabView(selection: $selection) {
                TodayView(tabSelection: $selection)
                    .tag(0)
                    .tabItem {
                        Image(systemName: "bolt.fill")
                        Text(shared.localizedString("LABEL_TODAY"))
                    }
                    .background(Color.backgroundColor.edgesIgnoringSafeArea(.all))

                TomorrowView(tabSelection: $selection)
                    .tag(1)
                    .tabItem {
                        Image(systemName: "clock.fill")
                        Text(shared.localizedString("LABEL_TOMORROW"))
                    }
                    .background(Color.backgroundColor.edgesIgnoringSafeArea(.all))

                SettingsView()
                    .tag(2)
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text(shared.localizedString("LABEL_SETTINGS"))
                    }
                    .background(Color.backgroundColor.edgesIgnoringSafeArea(.all))
            }
            .applyTabTint(selectedTintColor)
            .hideTabBarBackground()
            .onAppear { setTabBarTransparentAppearance() }
        }
    }
}

private extension View {
    @ViewBuilder
    func applyTabTint(_ color: Color) -> some View {
        self.tint(color)
    }
    
    @ViewBuilder
    func hideTabBarBackground() -> some View {
        self.toolbarBackground(.hidden, for: .tabBar)
    }
}

struct TabBarView_Previews: PreviewProvider {
    static var previews: some View {
        TabBarView(selection: Binding.constant(0))
            .environmentObject(Globals())
            .previewLayout(.sizeThatFits)
    }
}


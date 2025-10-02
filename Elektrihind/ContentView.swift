//
//  ContentView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var shared: Globals
    @EnvironmentObject var networkManager: NetworkManager
    @State private var tabBarSelection = 0
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.tabBarBackground)
        // Unselected items: use a neutral color
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.inlineLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.compactInlineLayoutAppearance.normal.iconColor = UIColor.systemGray
        // Selected items: use the app's accent color
        let selectedColor = UIColor.systemBlue
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.inlineLayoutAppearance.selected.iconColor = selectedColor
        appearance.compactInlineLayoutAppearance.selected.iconColor = selectedColor

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    var body: some View {
        if networkManager.isConnected {
            TabBarView(selection: $tabBarSelection)
                .onAppear() {
                    shared.getSavedSettings()
                }
        } else {
            ConnectionLostView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(ColorScheme.allCases, id: \.self) {
            ContentView().preferredColorScheme($0)
        }
    }
}


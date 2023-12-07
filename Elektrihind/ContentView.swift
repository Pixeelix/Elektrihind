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
        UITabBar.appearance().backgroundColor = UIColor(Color.tabBarBackground)
    }
    
    var body: some View {
        if networkManager.isConnected {
            TabView(selection: $tabBarSelection) {
                TodayView(tabSelection: $tabBarSelection)
                    .tag(0)
                    .background(Color.backgroundColor.edgesIgnoringSafeArea(.all))
                TomorrowView(tabSelection: $tabBarSelection)
                    .tag(1)
                    .background(Color.backgroundColor.edgesIgnoringSafeArea(.all))
    //          Text("Hea teada")
    //              .tag(2)
    //              .background(backGroundColor().edgesIgnoringSafeArea(.all))
                SettingsView()
                    .tag(2)
                    .background(Color.backgroundColor.edgesIgnoringSafeArea(.all))
            }
            .onAppear() {
                shared.getSavedSettings()
            }
            .overlay(TabBarView(selection: $tabBarSelection), alignment: .bottom)
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

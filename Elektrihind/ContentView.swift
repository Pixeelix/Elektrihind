//
//  ContentView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var networkManager: NetworkManager
    @State private var tabBarSelection = 0
    
    var body: some View {
        if networkManager.isConnected {
            TabBarView(selection: $tabBarSelection)
                .onAppear() {
                    settings.getSavedSettings()
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


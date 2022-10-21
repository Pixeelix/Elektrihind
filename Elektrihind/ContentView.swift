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
        UITabBar.appearance().backgroundColor = UIColor(named: "tabBarBackground")
    }
    
    var body: some View {
        if networkManager.isConnected {
            TabView(selection: $tabBarSelection) {
                TodayView()
                    .tag(0)
                TomorrowView()
                    .tag(1)
                GoodToKnowView()
                  .tag(2)
                SettingsView()
                    .tag(3)
            }
            .onAppear() {
                shared.getSavedSettings()
            }
            .overlay(TabBarView(selection: $tabBarSelection), alignment: .bottom)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        } else {
            ZStack {
                backGroundColor().ignoresSafeArea()
                
                VStack {
                    Image(systemName: "wifi.slash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .foregroundColor(.white)
                    
                    Text(shared.localizedString("TEXT_CONNECTION_LOST"))
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding()
                    
                    Button {
                        self.settingsOpener()
                    } label: {
                        Text(shared.localizedString("TITLE_OPEN_SETTINGS"))
                            .padding()
                            .font(.headline)
                            .foregroundColor(Color("blueGrayText"))
                    }
                    .frame(width: 160)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .padding()
                }
            }
        }
    }
    
    private func settingsOpener(){
        if let url = URL(string: "App-prefs:") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static let shared = Globals()
    static let networkManager = NetworkManager()
    static var previews: some View {
        ForEach(ColorScheme.allCases, id: \.self) {
            ContentView()
                .environmentObject(shared)
                .environmentObject(networkManager)
                .preferredColorScheme($0)
        }
    }
}


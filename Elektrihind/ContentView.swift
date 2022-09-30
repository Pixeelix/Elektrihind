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
                    .background(backGroundColor().edgesIgnoringSafeArea(.all))
                TomorrowView()
                    .tag(1)
                    .background(backGroundColor().edgesIgnoringSafeArea(.all))
    //          Text("Hea teada")
    //              .tag(2)
    //              .background(backGroundColor().edgesIgnoringSafeArea(.all))
                SettingsView()
                    .tag(2)
                    .background(backGroundColor().edgesIgnoringSafeArea(.all))
            }
            .onAppear() {
                shared.getSavedSettings()
            }
            .overlay(TabBarView(selection: $tabBarSelection), alignment: .bottom)
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
    
    func backGroundColor() -> LinearGradient {
       return LinearGradient(gradient: Gradient(colors: [Color("backgroundTop"), Color("backgroundBottom")]), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(ColorScheme.allCases, id: \.self) {
            ContentView().preferredColorScheme($0)
        }
    }
}

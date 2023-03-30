//
//  ContentView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var shared: Globals
    @EnvironmentObject var networkManager: NetworkManager
    @State private var tabBarSelection = 0
    @State var dataLastLoaded: Date? = nil
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
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
            .onReceive(timer) { time in
                loadDataIfNeeded()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    loadDataIfNeeded()
                }
            }
            .onAppear() {
                loadDataIfNeeded()
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
    
    func loadDataIfNeeded() {
        if let dataLastLoaded = dataLastLoaded {
            let lastLoadedHour = Calendar.current.component(.hour, from: Date())
            let currentHour = Calendar.current.component(.hour, from: dataLastLoaded)
            if lastLoadedHour != currentHour ||
                dataLastLoaded.addingTimeInterval(3600) < Date() {
                loadData()
            } else {
                return
            }
        } else {
            loadData()
        }
    }
    
    func loadData() {
        Network().loadCurrentPrice { data in
            shared.currentPrice = data
        }
        Network().loadFullDayData(.today) { data in
            shared.todayFullDayData = data
        }
        Network().loadFullDayData(.tomorrow) { data in
            shared.missingTomorrowData = data.count <= 2
            shared.tomorrowFullDayData = data
        }
        self.dataLastLoaded = Date()
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

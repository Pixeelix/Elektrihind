//
//  ElektrihindApp.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import SwiftUI
import GoogleMobileAds
import FirebaseCore

@main
struct ElektrihindApp: App {
    @StateObject var networkManager = NetworkManager()
    @StateObject var shared = Globals()
    init() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        FirebaseApp.configure()
    }
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(networkManager)
                    .environmentObject(shared)
                UMPWrapper(canLoadAdsCallback: {
                    debugPrint("Can load ads now")
                })
                .disabled(true)
            }
            
        }
    }
}



//
//  ElektrihindApp.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import SwiftUI
import GoogleMobileAds
import FirebaseCore
import AppTrackingTransparency
import FBAudienceNetwork

@main
struct ElektrihindApp: App {
    @StateObject var networkManager = NetworkManager()
    @StateObject var shared = Globals()
    init() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        FirebaseApp.configure()
        FBAdSettings.setAdvertiserTrackingEnabled(true)
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(networkManager)
                .environmentObject(shared)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                            ATTrackingManager.requestTrackingAuthorization(completionHandler: { status in })
                        }
            
//            ZStack {
//
//                UMPWrapper(canLoadAdsCallback: {
//                    debugPrint("Can load ads now")
//                })
//                .disabled(true)
//            }
            
        }
    }
}



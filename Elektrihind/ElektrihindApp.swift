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
    @State var adStatus: Int = 0
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                switch adStatus {
                case 0:
                    HStack {}
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                    .background(Color.backgroundColor.edgesIgnoringSafeArea(.all))
                case 1:
                    ContentView()
                        .environmentObject(networkManager)
                        .environmentObject(shared)
                    UMPWrapper(canLoadAdsCallback: {
                        debugPrint("Can load ads now")
                    })
                    .disabled(true)
                case 2:
                    ContentView()
                        .environmentObject(networkManager)
                        .environmentObject(shared)
                default:
                    ContentView()
                        .environmentObject(networkManager)
                        .environmentObject(shared)
                }
            }.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                ATTrackingManager.requestTrackingAuthorization(completionHandler: { status in
                    switch status {
                    case .authorized:
                        adStatus = 1
                    case .notDetermined, .restricted, .denied:
                        adStatus = 2
                    @unknown default:
                        adStatus = 2
                    }
                    print("STATUS: \(status)") })
            }
        }
    }
}

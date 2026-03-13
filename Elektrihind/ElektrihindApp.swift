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

enum AdStatus {
    case initializing
    case authorized
    case restricted
}

@main
struct ElektrihindApp: App {
    @StateObject var networkManager = NetworkManager()
    @StateObject var settings = AppSettings()
    @State private var adStatus: AdStatus = .initializing
    @State private var canLoadAds: Bool = false
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                switch adStatus {
                case .initializing:
                    ZStack {
                        Color.backgroundColor.edgesIgnoringSafeArea(.all)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                case .authorized:
                    ContentView()
                        .environmentObject(networkManager)
                        .environmentObject(settings)
                        .background(
                            UMPWrapper(canLoadAdsCallback: {
                                debugPrint("Can load ads now")
                                // Start AdMob once consent is available
                                if !canLoadAds {
                                    canLoadAds = true
                                    MobileAds.shared.start()
                                }
                            })
                            .allowsHitTesting(false)
                        )
                case .restricted:
                    ContentView()
                        .environmentObject(networkManager)
                        .environmentObject(settings)
                        .onAppear {
                            if !canLoadAds {
                                canLoadAds = true
                                MobileAds.shared.start()
                            }
                        }
                }
            }.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                ATTrackingManager.requestTrackingAuthorization(completionHandler: { status in
                    switch status {
                    case .authorized:
                        adStatus = .authorized
                    case .notDetermined, .restricted, .denied:
                        adStatus = .restricted
                    @unknown default:
                        adStatus = .restricted
                    }
                    print("STATUS: \(status)") })
            }
        }
    }
}

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
import BackgroundTasks

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
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BGScheduler.taskIdentifier, using: nil) { task in
            BGScheduler.handle(task as! BGAppRefreshTask)
        }
    }
    
    private func requestATTIfNeeded() {
        guard adStatus == .initializing else { return }
        ATTrackingManager.requestTrackingAuthorization(completionHandler: { status in
            FBAdSettings.setAdvertiserTrackingEnabled(status == .authorized)
            switch status {
            case .authorized:
                adStatus = .authorized
            case .notDetermined, .restricted, .denied:
                adStatus = .restricted
            @unknown default:
                adStatus = .restricted
            }
            print("STATUS: \(status)")
        })
        Task { @MainActor in
            await NotificationService.shared.runForegroundCheck(settings: settings)
        }
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
            }
            .onAppear {
                if UIApplication.shared.applicationState == .active {
                    requestATTIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                requestATTIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                PriceAPI.resetSession()
            }
        }
    }
}



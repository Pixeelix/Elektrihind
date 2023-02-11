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
    init() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        FirebaseApp.configure()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(NetworkManager())
                .environmentObject(Globals())
        }
    }
}

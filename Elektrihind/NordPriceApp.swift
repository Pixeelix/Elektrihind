//
//  NordPriceApp.swift
//  NordPrice
//
//  Created by Martin Pihooja on 17.11.2021.
//

import SwiftUI
import GoogleMobileAds
import FirebaseCore
import FirebaseMessaging
import AppTrackingTransparency
import FBAudienceNetwork
import UIKit
import UserNotifications

enum AdStatus {
    case initializing
    case authorized
    case restricted
}

final class AppNavigation: ObservableObject {
    static let shared = AppNavigation()

    @Published var selectedTab = 0

    func openTomorrowPrices() {
        selectedTab = 1
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationService.shared.updateRemoteDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationService.shared.remoteRegistrationDidFail(error)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        NotificationService.shared.updateFCMToken(fcmToken)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }

        let userInfo = response.notification.request.content.userInfo
        guard Self.opensTomorrowPriceView(userInfo: userInfo) else { return }

        await MainActor.run {
            AppNavigation.shared.openTomorrowPrices()
        }
    }

    private static func opensTomorrowPriceView(userInfo: [AnyHashable: Any]) -> Bool {
        guard let type = userInfo["type"] as? String else { return false }
        return type.hasPrefix("price_threshold_")
    }
}

@main
struct NordPriceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var networkManager = NetworkManager()
    @StateObject var navigation = AppNavigation.shared
    @StateObject var settings = AppSettings()
    @State private var adStatus: AdStatus = AppRuntimeConfiguration.skipsAdConsent ? .restricted : .initializing
    @State private var canLoadAds: Bool = false
    
    private func requestATTIfNeeded() {
        guard !AppRuntimeConfiguration.skipsAdConsent else {
            adStatus = .restricted
            return
        }
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
                        .environmentObject(navigation)
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
                        .environmentObject(navigation)
                        .environmentObject(settings)
                        .onAppear {
                            if !AppRuntimeConfiguration.skipsAdConsent && !canLoadAds {
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

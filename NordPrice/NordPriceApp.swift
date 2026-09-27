//
//  NordPriceApp.swift
//  NordPrice
//
//  Created by Martin Pihooja on 17.11.2021.
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

final class AppNavigation: ObservableObject {
    static let shared = AppNavigation()

    @Published var selectedTab: Int = {
        #if DEBUG
        // Lets screenshot automation open a specific tab: -NordPriceInitialTab 1
        return UserDefaults.standard.integer(forKey: "NordPriceInitialTab")
        #else
        return 0
        #endif
    }()

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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(networkManager)
                .environmentObject(navigation)
                .environmentObject(settings)
                .onAppear {
                    // UMP can only present its form while the app is active.
                    if UIApplication.shared.applicationState == .active {
                        ConsentManager.shared.gatherConsent()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    ConsentManager.shared.gatherConsent()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    PriceAPI.resetSession()
                }
        }
    }
}

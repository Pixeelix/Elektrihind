//
//  AdConstants.swift
//  NordPrice
//
//  Centralized ad unit IDs.
//

import Foundation

enum AppRuntimeConfiguration {
    static let debugUseTestDataKey = "debugUseTestData"
    private static let appGroupID = "group.koodipardik.Elektrihind"

    static var isScreenshotMode: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-NordPriceLiveData") {
            return false
        }

        #if targetEnvironment(simulator)
        return true
        #else
        return ProcessInfo.processInfo.arguments.contains("-NordPriceScreenshotMode")
        #endif
        #else
        return false
        #endif
    }

    static var defaultUsesSamplePriceData: Bool {
        #if DEBUG
        return isScreenshotMode
        #else
        return false
        #endif
    }

    static var usesSamplePriceData: Bool {
        #if DEBUG
        if let saved = UserDefaults.standard.object(forKey: debugUseTestDataKey) as? Bool {
            return saved
        }
        if let saved = UserDefaults(suiteName: appGroupID)?.object(forKey: debugUseTestDataKey) as? Bool {
            return saved
        }
        return defaultUsesSamplePriceData
        #else
        return false
        #endif
    }

    static var hidesAdBanners: Bool { isScreenshotMode }
    static var skipsAdConsent: Bool { isScreenshotMode }
}

enum AdUnit {
    static let todayBanner = "ca-app-pub-5431783362632568/4212512484"
    static let tomorrowNoDataBanner = "ca-app-pub-5431783362632568/8076084809"
    static let tomorrowDataBanner = "ca-app-pub-5431783362632568/3104542071"
    static let settingsBanner = "ca-app-pub-5431783362632568/6165348123"
}

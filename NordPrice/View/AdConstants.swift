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

    static let debugHideAdsKey = "debugHideAds"

    /// Screenshots never show ads, and a debug build also honours the "no ads" switch in
    /// Settings. The switch is compiled out of release builds, so a stray preference key can
    /// never silence the app for a user.
    static var hidesAdBanners: Bool {
        if isScreenshotMode { return true }
        #if DEBUG
        return boolPreference(debugHideAdsKey)
        #else
        return false
        #endif
    }

    /// Stored value of the debug switch, independent of whether ads are hidden right now
    /// (screenshot mode hides them too).
    static var hideAdsPreference: Bool {
        #if DEBUG
        return boolPreference(debugHideAdsKey)
        #else
        return false
        #endif
    }

    #if DEBUG
    private static func boolPreference(_ key: String) -> Bool {
        if let value = UserDefaults.standard.object(forKey: key) as? Bool { return value }
        if let value = UserDefaults(suiteName: appGroupID)?.object(forKey: key) as? Bool { return value }
        return false
    }
    #endif

    static var skipsAdConsent: Bool { isScreenshotMode }
}

enum AdUnit {
    static let todayBanner = "ca-app-pub-5431783362632568/4212512484"
    static let tomorrowNoDataBanner = "ca-app-pub-5431783362632568/8076084809"
    static let tomorrowDataBanner = "ca-app-pub-5431783362632568/3104542071"
    static let historyBanner = "ca-app-pub-5431783362632568/3201163730"
}

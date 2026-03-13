//
//  CacheKeyGenerator.swift
//  Elektrihind
//
//  Shared cache key generation for price data.
//

import Foundation

enum CacheKeyGenerator {
    /// Returns the lowercase region key used in cache keys.
    static func regionKey(for region: Region) -> String {
        switch region {
        case .estonia: return "ee"
        case .latvia: return "lv"
        case .lithuania: return "lt"
        case .finland: return "fi"
        }
    }

    /// Returns the lowercase region key for a region code string (e.g. "EE").
    static func regionKey(forCode regionCode: String) -> String {
        switch regionCode.uppercased() {
        case "EE": return "ee"
        case "LV": return "lv"
        case "LT": return "lt"
        case "FI": return "fi"
        default: return "ee"
        }
    }

    /// Generates a versioned cache key for a given day and region.
    static func cacheKey(for day: Day, region: Region) -> String {
        let interval = UTCInterval.interval(for: day)
        return "prices_v1_\(regionKey(for: region))_\(interval.start)"
    }

    /// Generates a versioned cache key for today using a region code string.
    static func cacheKeyForToday(regionCode: String) -> String {
        let startString = UTCInterval.todayStartUTC()
        return "prices_v1_\(regionKey(forCode: regionCode))_\(startString)"
    }
}

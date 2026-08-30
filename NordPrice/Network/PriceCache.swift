//
//  PriceCache.swift
//  NordPrice
//
//  Cache layer for price data using App Group UserDefaults.
//  The storage format and day-completeness rules live in SharedPriceCache so the
//  widget extension uses exactly the same implementation.
//

import Foundation

class PriceCache {
    func load(day: Day, region: Region) -> [PriceData]? {
        return SharedPriceCache.load(day: day, region: region)
    }

    /// - Returns: `true` when a payload covering the whole day was written.
    @discardableResult
    func save(day: Day, region: Region, payload: Data, items: [PriceData]) -> Bool {
        return SharedPriceCache.save(day: day, region: region, payload: payload, items: items)
    }

    static func extractItems(_ data: Data, for region: Region) throws -> [PriceData] {
        return try SharedPriceCache.extractItems(data, for: region)
    }
}

//
//  PriceCache.swift
//  Elektrihind
//
//  Cache layer for price data using App Group UserDefaults.
//

import Foundation

class PriceCache {
    private let appGroupID = "group.koodipardik.Elektrihind"
    private var sharedDefaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

    struct CachedPayload: Codable {
        let startUTC: String
        let isComplete: Bool
        let payload: Data
        let fetchedAt: Date
    }

    func load(day: Day, region: Region) -> [PriceData]? {
        let key = CacheKeyGenerator.cacheKey(for: day, region: region)
        guard let stored = sharedDefaults.data(forKey: key) else { return nil }
        guard let cached = try? JSONDecoder().decode(CachedPayload.self, from: stored) else { return nil }
        guard cached.isComplete else { return nil }
        guard let items = try? Self.extractItems(cached.payload, for: region) else { return nil }
        let expected = Self.expectedHourCount(for: day)
        guard items.count == expected else { return nil }
        return items
    }

    func save(day: Day, region: Region, payload: Data, itemsCount: Int) {
        let isComplete = itemsCount == Self.expectedHourCount(for: day)
        let cached = CachedPayload(
            startUTC: UTCInterval.interval(for: day).start,
            isComplete: isComplete,
            payload: payload,
            fetchedAt: Date()
        )
        if let data = try? JSONEncoder().encode(cached) {
            let key = CacheKeyGenerator.cacheKey(for: day, region: region)
            sharedDefaults.set(data, forKey: key)
        }
    }

    static func extractItems(_ data: Data, for region: Region) throws -> [PriceData] {
        let decoded = try JSONDecoder().decode(NordPoolCountriesData.self, from: data)
        switch region {
        case .estonia: return decoded.data.ee
        case .latvia: return decoded.data.lv
        case .lithuania: return decoded.data.lt
        case .finland: return decoded.data.fi
        }
    }

    static func expectedHourCount(for day: Day) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let localStart: Date
        switch day {
        case .today:
            localStart = calendar.startOfDay(for: now)
        case .tomorrow:
            let t = calendar.date(byAdding: .day, value: 1, to: now)!
            localStart = calendar.startOfDay(for: t)
        }
        let nextLocalStart = calendar.date(byAdding: .day, value: 1, to: localStart)!
        return calendar.dateComponents([.hour], from: localStart, to: nextLocalStart).hour ?? 24
    }
}

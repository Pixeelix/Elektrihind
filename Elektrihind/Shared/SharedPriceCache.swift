//
//  SharedPriceCache.swift
//  NordPrice
//
//  App Group price cache shared by the app and the widget extension.
//
//  The app and the widget used to keep two byte-identical copies of this logic,
//  which is how they drifted apart: both validated a day's payload by comparing
//  the item count to the number of *hours* in the local day, so once Elering
//  switched to 15-minute resolution nothing was ever considered complete and the
//  cache could be written but never read back.
//

import Foundation

enum SharedPriceCache {
    static let appGroupID = "group.koodipardik.Elektrihind"

    static var sharedDefaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

    struct CachedPayload: Codable {
        let startUTC: String
        let isComplete: Bool
        let payload: Data
        let fetchedAt: Date
    }

    // MARK: - Local day geometry

    /// Start of the local day for `day` (device time zone).
    static func localDayStart(for day: Day) -> Date {
        let calendar = Calendar.current
        let now = Date()
        switch day {
        case .today:
            return calendar.startOfDay(for: now)
        case .tomorrow:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(24 * 3600)
            return calendar.startOfDay(for: tomorrow)
        }
    }

    /// Seconds in the local day for `day`. DST aware: 23 h, 24 h or 25 h.
    static func daySeconds(for day: Day) -> TimeInterval {
        let calendar = Calendar.current
        let start = localDayStart(for: day)
        guard let next = calendar.date(byAdding: .day, value: 1, to: start) else { return 24 * 3600 }
        return next.timeIntervalSince(start)
    }

    /// True when `items` cover the whole local day at a uniform interval.
    ///
    /// The interval is derived from the data (median gap between consecutive
    /// timestamps) rather than assumed, so this keeps working if Elering changes
    /// resolution again — while still rejecting genuinely partial days.
    static func covers(day: Day, items: [PriceData]) -> Bool {
        guard items.count >= 2 else { return false }
        let sorted = items.sorted { $0.timestamp < $1.timestamp }

        // The payload must start exactly at the local day start.
        let expectedStart = localDayStart(for: day).timeIntervalSince1970
        guard abs(sorted[0].timestamp - expectedStart) < 1 else { return false }

        var gaps: [TimeInterval] = []
        gaps.reserveCapacity(sorted.count - 1)
        for index in 1..<sorted.count {
            gaps.append(sorted[index].timestamp - sorted[index - 1].timestamp)
        }
        gaps.sort()
        let interval = gaps[gaps.count / 2]
        guard interval > 0 else { return false }

        return Double(sorted.count) * interval >= daySeconds(for: day)
    }

    // MARK: - Payload decoding

    static func extractItems(_ data: Data, for region: Region) throws -> [PriceData] {
        let decoded = try JSONDecoder().decode(NordPoolCountriesData.self, from: data)
        switch region {
        case .estonia: return decoded.data.ee
        case .latvia: return decoded.data.lv
        case .lithuania: return decoded.data.lt
        case .finland: return decoded.data.fi
        }
    }

    static func region(forCode code: String) -> Region {
        return Region(rawValue: code.uppercased()) ?? .estonia
    }

    // MARK: - Read

    /// Returns cached items for `day` only when the blob is fresh (its stored
    /// day start still matches `day`) and covers the whole day.
    static func load(day: Day, region: Region) -> [PriceData]? {
        guard let cached = storedPayload(day: day, region: region) else { return nil }
        guard cached.isComplete else { return nil }
        guard let items = try? extractItems(cached.payload, for: region) else { return nil }
        guard covers(day: day, items: items) else { return nil }
        return items
    }

    /// Returns whatever is cached for `day`, ignoring the completeness flag.
    /// Used as a last-resort fallback when a live fetch fails: stale-but-real
    /// prices beat an empty widget.
    static func loadBestEffort(day: Day, region: Region) -> [PriceData]? {
        guard let cached = storedPayload(day: day, region: region) else { return nil }
        guard let items = try? extractItems(cached.payload, for: region), !items.isEmpty else { return nil }
        return items
    }

    private static func storedPayload(day: Day, region: Region) -> CachedPayload? {
        let key = CacheKeyGenerator.cacheKey(for: day, region: region)
        guard let stored = sharedDefaults.data(forKey: key) else { return nil }
        guard let cached = try? JSONDecoder().decode(CachedPayload.self, from: stored) else { return nil }
        // The key already encodes the day start, but verify the blob agrees so a
        // key written under a different time zone offset can never be trusted.
        guard cached.startUTC == UTCInterval.interval(for: day).start else { return nil }
        return cached
    }

    // MARK: - Write

    /// Stores `payload` under the key for `day`/`region`.
    /// - Returns: `true` when a payload covering the whole day was stored, i.e.
    ///   when there is genuinely new complete data worth telling the widget about.
    @discardableResult
    static func save(day: Day, region: Region, payload: Data, items: [PriceData]) -> Bool {
        let isComplete = covers(day: day, items: items)
        let cached = CachedPayload(
            startUTC: UTCInterval.interval(for: day).start,
            isComplete: isComplete,
            payload: payload,
            fetchedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(cached) else { return false }
        sharedDefaults.set(data, forKey: CacheKeyGenerator.cacheKey(for: day, region: region))
        pruneStaleKeys()
        return isComplete
    }

    // MARK: - Pruning

    /// Removes every `prices_v1_*` entry that is not today's or tomorrow's.
    /// Each blob holds the full four-country JSON payload, so without this they
    /// accumulate one per (region × day) forever.
    static func pruneStaleKeys() {
        let defaults = sharedDefaults
        var keep = Set<String>()
        for region in Region.allRegions {
            keep.insert(CacheKeyGenerator.cacheKey(for: .today, region: region))
            keep.insert(CacheKeyGenerator.cacheKey(for: .tomorrow, region: region))
        }
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("prices_v1_") && !keep.contains(key) {
            defaults.removeObject(forKey: key)
        }
    }
}

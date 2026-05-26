//
//  PriceRepository.swift
//  NordPrice
//
//  Orchestrates cache and API: tries cache first, falls back to network, saves to cache.
//

import Foundation

class PriceRepository {
    private let cache = PriceCache()
    private let api = PriceAPI()

    func loadFullDayData(_ day: Day, region: Region) async throws -> [PriceData] {
        if AppRuntimeConfiguration.usesSamplePriceData {
            return ScreenshotPriceData.fullDayData(day, region: region)
        }

        // 1) Try cache first
        if let cached = cache.load(day: day, region: region) {
            return cached
        }

        // 2) Fetch from network
        let rawData = try await api.fetchDayData(day)

        // 3) Decode and extract region-specific items
        let items = try PriceCache.extractItems(rawData, for: region)

        // 4) Save to cache
        cache.save(day: day, region: region, payload: rawData, itemsCount: items.count)

        return items
    }
}

private enum ScreenshotPriceData {
    static func fullDayData(_ day: Day, region: Region, referenceDate: Date = Date()) -> [PriceData] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZoneHelper.timeZone(for: region)

        let targetDate: Date
        switch day {
        case .today:
            targetDate = referenceDate
        case .tomorrow:
            targetDate = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate.addingTimeInterval(24 * 3600)
        }

        let dayStart = calendar.startOfDay(for: targetDate)
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)
        let intervalSeconds: TimeInterval = 15 * 60
        let intervalCount = max(1, Int(nextDayStart.timeIntervalSince(dayStart) / intervalSeconds))
        let basePrices = hourlyPrices(for: day)
        let quarterAdjustments = [-1.8, 0.7, 2.2, -0.6]
        let regionOffset = offset(for: region)

        return (0..<intervalCount).map { index in
            let hourIndex = min(basePrices.count - 1, index / 4)
            let timestamp = dayStart.addingTimeInterval(TimeInterval(index) * intervalSeconds).timeIntervalSince1970
            let price = basePrices[hourIndex] + quarterAdjustments[index % quarterAdjustments.count] + regionOffset
            return PriceData(timestamp: timestamp, price: price)
        }
    }

    private static func hourlyPrices(for day: Day) -> [Double] {
        switch day {
        case .today:
            return [
                54, 48, 43, 40, 46, 68, 112, 154,
                139, 104, 82, 71, 64, 58, 55, 63,
                91, 148, 183, 144, 101, 78, 65, 57
            ]
        case .tomorrow:
            return [
                38, 32, 27, 24, 21, 33, 58, 84,
                69, 36, 13, -9, -18, -24, -14, 6,
                45, 98, 129, 94, 59, 43, 35, 29
            ]
        }
    }

    private static func offset(for region: Region) -> Double {
        switch region {
        case .estonia: return 0
        case .latvia: return 3
        case .lithuania: return 5
        case .finland: return -4
        }
    }
}

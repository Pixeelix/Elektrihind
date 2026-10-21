//
//  HistoryRepository.swift
//  NordPrice
//
//  Daily average prices for the history tab. Data is fetched one calendar month
//  at a time (a month is ~70 KB compressed; a whole year in one request is ~6 MB
//  and slow). Months that have ended never change, so their daily averages are
//  kept on disk; the current month is refetched once a day.
//

import Foundation

/// Average Nord Pool price of one day, raw €/MWh before unit conversion and VAT.
struct DailyAveragePrice: Codable {
    /// Start of the day in `HistoryCalendar.calendar`.
    let dayStart: TimeInterval
    let price: Double
}

enum HistoryCalendar {
    /// All four markets are on Eastern European Time, so one calendar serves every
    /// region. Weeks start on Monday, as they do in all four countries.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Tallinn") ?? .current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    /// Elering's price data starts in 2012 (Finland) and mid-2013 (Baltics).
    static let earliestDate: Date = calendar.date(from: DateComponents(year: 2013, month: 1, day: 1))!

    /// "2026-09": key of the month containing `date`.
    static func monthKey(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    static func monthStart(for date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}

actor HistoryRepository {
    static let shared = HistoryRepository()

    /// monthKey -> region code -> daily averages, for months that have ended.
    private var completedMonths: [String: [String: [DailyAveragePrice]]] = [:]
    /// The month still in progress, kept in memory only.
    private var currentMonth: (key: String, fetchedDay: Date, data: [String: [DailyAveragePrice]])?
    private var didLoadFromDisk = false
    private let api = PriceAPI()

    private static let fileURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("price_history_v1.json")
    }()

    /// Daily averages for every day of the given months (each a month start).
    func dailyAverages(region: Region, months: [Date]) async throws -> [DailyAveragePrice] {
        if AppRuntimeConfiguration.usesSamplePriceData {
            return months.flatMap { SampleHistoryData.month($0, region: region) }
        }

        loadFromDiskIfNeeded()

        let results = try await withThrowingTaskGroup(of: [String: [DailyAveragePrice]].self) { group in
            for month in months {
                group.addTask { try await self.monthData(for: month) }
            }
            var all: [DailyAveragePrice] = []
            for try await monthData in group {
                all.append(contentsOf: monthData[region.rawValue.lowercased()] ?? [])
            }
            return all
        }
        return results.sorted { $0.dayStart < $1.dayStart }
    }

    private func monthData(for monthStart: Date) async throws -> [String: [DailyAveragePrice]] {
        let calendar = HistoryCalendar.calendar
        let key = HistoryCalendar.monthKey(for: monthStart)
        let today = calendar.startOfDay(for: Date())

        if let cached = completedMonths[key] {
            return cached
        }
        if let current = currentMonth, current.key == key, current.fetchedDay == today {
            return current.data
        }

        guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return [:] }
        let raw = try await api.fetchRange(start: monthStart, end: monthEnd.addingTimeInterval(-0.001))
        let decoded = try JSONDecoder().decode(NordPoolCountriesData.self, from: raw)
        let data: [String: [DailyAveragePrice]] = [
            "ee": Self.dailyAverages(decoded.data.ee),
            "fi": Self.dailyAverages(decoded.data.fi),
            "lt": Self.dailyAverages(decoded.data.lt),
            "lv": Self.dailyAverages(decoded.data.lv)
        ]

        if monthEnd <= today {
            completedMonths[key] = data
            saveToDisk()
        } else {
            currentMonth = (key, today, data)
        }
        return data
    }

    /// Mean of every interval in each day. Older data is hourly and newer data is
    /// 15-minute, but within one day all intervals have the same length, so a
    /// plain mean is the time-weighted average either way.
    private static func dailyAverages(_ points: [PriceData]) -> [DailyAveragePrice] {
        let calendar = HistoryCalendar.calendar
        var sums: [TimeInterval: (sum: Double, count: Int)] = [:]
        for point in points {
            let day = calendar.startOfDay(for: Date(timeIntervalSince1970: point.timestamp)).timeIntervalSince1970
            let current = sums[day] ?? (0, 0)
            sums[day] = (current.sum + point.price, current.count + 1)
        }
        return sums
            .map { DailyAveragePrice(dayStart: $0.key, price: $0.value.sum / Double($0.value.count)) }
            .sorted { $0.dayStart < $1.dayStart }
    }

    private func loadFromDiskIfNeeded() {
        guard !didLoadFromDisk else { return }
        didLoadFromDisk = true
        guard let data = try? Data(contentsOf: Self.fileURL),
              let saved = try? JSONDecoder().decode([String: [String: [DailyAveragePrice]]].self, from: data) else { return }
        completedMonths.merge(saved) { current, _ in current }
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(completedMonths) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}

/// Deterministic made-up history for screenshot mode / simulator builds.
private enum SampleHistoryData {
    static func month(_ monthStart: Date, region: Region) -> [DailyAveragePrice] {
        let calendar = HistoryCalendar.calendar
        let today = calendar.startOfDay(for: Date())
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let regionOffset: Double = region == .finland ? -12 : (region == .estonia ? 0 : 4)

        return range.compactMap { dayNumber -> DailyAveragePrice? in
            guard let day = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthStart),
                  day <= today else { return nil }
            // A rolled day comes from the same curve as the price screens, so a bar in the
            // history chart and that day's own view describe the same invented market.
            if let rolled = SamplePriceCurve.dailyAverage(for: day) {
                return DailyAveragePrice(dayStart: day.timeIntervalSince1970,
                                         price: max(4, rolled + regionOffset))
            }

            let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: day) ?? 1)
            let weekday = calendar.component(.weekday, from: day)
            // Winter is expensive, summer cheap, weekends a little cheaper.
            let seasonal = 95 + 45 * cos((dayOfYear - 15) / 365 * 2 * .pi)
            let weekly = (weekday == 1 || weekday == 7) ? -18.0 : 6.0
            let noise = 22 * sin(dayOfYear * 1.7) + 12 * sin(dayOfYear * 0.53)
            return DailyAveragePrice(dayStart: day.timeIntervalSince1970,
                                     price: max(4, seasonal + weekly + noise + regionOffset))
        }
    }
}

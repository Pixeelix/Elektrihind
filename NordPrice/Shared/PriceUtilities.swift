//
//  PriceUtilities.swift
//  NordPrice
//
//  Shared utility for aggregating 15-minute price data into hourly averages.
//

import Foundation

enum PriceUtilities {
    /// Aggregate 15-minute data points into hourly data points by averaging each group.
    static func aggregateToHourly(_ data: [PriceData]) -> [PriceData] {
        guard !data.isEmpty else { return [] }
        var buckets: [(time: TimeInterval, values: [Double])] = []
        var currentHourStart: TimeInterval? = nil
        var currentValues: [Double] = []
        let calendar = Calendar.current
        for point in data.sorted(by: { $0.timestamp < $1.timestamp }) {
            let date = Date(timeIntervalSince1970: point.timestamp)
            let comps = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            guard let hourDate = calendar.date(from: comps) else { continue }
            let hourStart = hourDate.timeIntervalSince1970
            if currentHourStart == nil {
                currentHourStart = hourStart
            }
            if hourStart != currentHourStart {
                if let start = currentHourStart, !currentValues.isEmpty {
                    let avg = currentValues.reduce(0, +) / Double(currentValues.count)
                    buckets.append((time: start, values: [avg]))
                }
                currentHourStart = hourStart
                currentValues = [point.price]
            } else {
                currentValues.append(point.price)
            }
        }
        if let start = currentHourStart, !currentValues.isEmpty {
            let avg = currentValues.reduce(0, +) / Double(currentValues.count)
            buckets.append((time: start, values: [avg]))
        }
        return buckets.map { PriceData(timestamp: $0.time, price: $0.values.first ?? 0) }
    }
}

// MARK: - Debug sample data

/// Seeded pseudo-random price curves for the debug random-data mode.
///
/// Here rather than in a new file because both the app and the widget target compile this
/// one, and the two have to show the same invented day. The seed travels through the app
/// group like the other debug preferences.
///
/// Generation is deterministic for a given roll: reloading a screen must not redraw a
/// different chart. With no roll stored, every caller falls back to its fixed screenshot
/// tables, so App Store screenshots stay exactly as they are.
enum SamplePriceCurve {
    private static let appGroupID = "group.koodipardik.Elektrihind"
    static let seedKey = "debugRandomSeed"

    /// The current roll, or `nil` when sample data should use the fixed tables.
    static var seed: UInt64? {
        for defaults in [UserDefaults(suiteName: appGroupID), .standard] {
            if let number = defaults?.object(forKey: seedKey) as? NSNumber, number.uint64Value > 0 {
                return number.uint64Value
            }
        }
        return nil
    }

    @discardableResult
    static func roll() -> UInt64 {
        // Any non-zero value works; staying under 2^62 keeps it inside every NSNumber width.
        let value = UInt64.random(in: 1..<(1 << 62))
        for defaults in [UserDefaults(suiteName: appGroupID), .standard] {
            defaults?.set(Int64(value), forKey: seedKey)
        }
        return value
    }

    static func clearRoll() {
        for defaults in [UserDefaults(suiteName: appGroupID), .standard] {
            defaults?.removeObject(forKey: seedKey)
        }
    }

    /// 24 hourly €/MWh values for one day: a two-peak curve with randomised depth, peak
    /// hours and jitter, so every roll looks like a different trading day and none look
    /// absurd. Negative night prices are left possible — they are real in this market.
    static func hourlyPrices(for day: Date) -> [Double]? {
        guard let roll = seed else { return nil }
        var rng = SeededRandom(seed: roll &+ day.daysSinceEpoch)
        let base = Double.random(in: -8...55, using: &rng)
        let morningHeight = Double.random(in: 5...95, using: &rng)
        let morningPeak = Double.random(in: 6...9, using: &rng)
        let eveningHeight = Double.random(in: 45...185, using: &rng)
        let eveningPeak = Double.random(in: 16...20, using: &rng)

        return (0..<24).map { hour in
            let h = Double(hour)
            let morning = morningHeight * exp(((h - morningPeak) * (h - morningPeak)) / -7)
            let evening = eveningHeight * exp(((h - eveningPeak) * (h - eveningPeak)) / -5)
            let jitter = Double.random(in: -9...9, using: &rng)
            return (base + morning + evening + jitter).rounded()
        }
    }

    /// Daily average for the history sample, taken from the same curve so a day's bar in
    /// the history chart and that day's own price screen would agree.
    static func dailyAverage(for day: Date) -> Double? {
        guard let prices = hourlyPrices(for: day) else { return nil }
        return prices.reduce(0, +) / Double(prices.count)
    }
}

/// SplitMix64: small, deterministic and independent of the system PRNG, which is the whole
/// point — the same roll has to produce the same day on every launch and in both targets.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private extension Date {
    /// Whole days since the epoch, so each calendar day gets its own curve while a given
    /// day stays stable across launches.
    var daysSinceEpoch: UInt64 {
        UInt64(max(0, timeIntervalSince1970 / 86_400).rounded(.down))
    }
}

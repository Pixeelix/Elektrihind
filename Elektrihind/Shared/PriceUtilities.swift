//
//  PriceUtilities.swift
//  Elektrihind
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

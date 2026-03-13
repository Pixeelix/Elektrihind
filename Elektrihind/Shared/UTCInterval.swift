//
//  UTCInterval.swift
//  Elektrihind
//
//  Shared UTC interval calculation for API requests.
//

import Foundation

enum UTCInterval {
    /// Computes the UTC start/end ISO8601 strings for a given day.
    static func interval(for day: Day) -> (start: String, end: String) {
        let calendar = Calendar.current
        let now = Date()
        let localStart: Date
        switch day {
        case .today:
            localStart = calendar.startOfDay(for: now)
        case .tomorrow:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            localStart = calendar.startOfDay(for: tomorrow)
        }
        let nextLocalStart = calendar.date(byAdding: .day, value: 1, to: localStart)!
        let endDate = nextLocalStart.addingTimeInterval(-0.001)

        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let startString = formatter.string(from: localStart)
        let endString = formatter.string(from: endDate)
        return (startString, endString)
    }

    /// Computes the UTC start ISO8601 string for today (used for cache keys).
    static func todayStartUTC() -> String {
        let calendar = Calendar.current
        let localStart = calendar.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: localStart)
    }
}

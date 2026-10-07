//
//  PriceAPI.swift
//  NordPrice
//
//  HTTP layer for fetching price data from Elering API.
//

import Foundation

enum PriceAPIError: Error {
    case badURL
    case requestFailed(statusCode: Int)
}

class PriceAPI {
    // Shared session across all PriceAPI instances. Explicit timeouts prevent stale
    // HTTP/2 connections (kept alive by URLSession.shared after backgrounding) from
    // blocking requests for minutes on resume. Call resetSession() when backgrounding
    // so the next foreground request opens a fresh connection instead of reusing a
    // dead socket.
    private static var session: URLSession = PriceAPI.makeSession()

    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }

    static func resetSession() {
        session.invalidateAndCancel()
        session = makeSession()
    }

    func fetchDayData(_ day: Day) async throws -> Data {
        let interval = UTCInterval.interval(for: day)
        return try await fetch(start: interval.start, end: interval.end)
    }

    /// Prices for an arbitrary period. Elering allows at most one year per request.
    func fetchRange(start: Date, end: Date) async throws -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return try await fetch(start: formatter.string(from: start), end: formatter.string(from: end))
    }

    private func fetch(start: String, end: String) async throws -> Data {
        guard let url = URL(string: "https://dashboard.elering.ee/api/nps/price?start=\(start)&end=\(end)") else {
            throw PriceAPIError.badURL
        }

        let (data, response) = try await PriceAPI.session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw PriceAPIError.requestFailed(statusCode: 0)
        }
        guard http.statusCode == 200 else {
            throw PriceAPIError.requestFailed(statusCode: http.statusCode)
        }
        return data
    }
}

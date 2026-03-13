//
//  PriceAPI.swift
//  Elektrihind
//
//  HTTP layer for fetching price data from Elering API.
//

import Foundation

enum PriceAPIError: Error {
    case badURL
    case requestFailed(statusCode: Int)
}

class PriceAPI {
    func fetchDayData(_ day: Day) async throws -> Data {
        let interval = UTCInterval.interval(for: day)
        guard let url = URL(string: "https://dashboard.elering.ee/api/nps/price?start=\(interval.start)&end=\(interval.end)") else {
            throw PriceAPIError.badURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw PriceAPIError.requestFailed(statusCode: 0)
        }
        guard http.statusCode == 200 else {
            throw PriceAPIError.requestFailed(statusCode: http.statusCode)
        }
        return data
    }
}

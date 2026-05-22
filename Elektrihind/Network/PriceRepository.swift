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

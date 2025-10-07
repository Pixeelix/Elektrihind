//
//  NetworkManager.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import Foundation
import SwiftUI
import Network

enum Day {
    case today
    case tomorrow
}

class NetworkManager: ObservableObject {
    let monitor = NWPathMonitor()
    let queue = DispatchQueue(label: "NetworkManager")
    @Published var isConnected = true
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

class NetworkService: ObservableObject {
    private enum NetworkError: Error {
        case badURL
        case requestFailed(statusCode: Int)
    }
    
    // Shared App Group for cache (used by app and widget)
    private let appGroupID = "group.koodipardik.Elektrihind"
    private var sharedDefaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }
    
    // MARK: - Simple day+region cache (UserDefaults)
    private struct CachedPayload: Codable {
        let startUTC: String
        let isComplete: Bool
        let payload: Data
        let fetchedAt: Date
    }

    private func regionKey(_ region: Region) -> String {
        switch region {
        case .estonia: return "ee"
        case .latvia: return "lv"
        case .lithuania: return "lt"
        case .finland: return "fi"
        }
    }

    private func cacheKey(for day: Day, region: Region) -> String {
        let interval = utcInterval(for: day)
        // Versioned key to allow future migrations
        return "prices_v1_\(regionKey(region))_\(interval.start)"
    }

    private func expectedHourCount(for day: Day) -> Int {
        // Compute local day length (23/24/25 hours depending on DST)
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
        let hours = calendar.dateComponents([.hour], from: localStart, to: nextLocalStart).hour ?? 24
        return hours
    }

    private func extractItems(_ data: Data, for region: Region) throws -> [PriceData] {
        let decodedNordPoolData = try JSONDecoder().decode(NordPoolCountriesData.self, from: data)
        switch region {
        case .estonia:
            return decodedNordPoolData.data.ee
        case .latvia:
            return decodedNordPoolData.data.lv
        case .lithuania:
            return decodedNordPoolData.data.lt
        case .finland:
            return decodedNordPoolData.data.fi
        }
    }

    private func loadFromCache(day: Day, region: Region) -> [PriceData]? {
        let key = cacheKey(for: day, region: region)
        guard let stored = sharedDefaults.data(forKey: key) else { return nil }
        guard let cached = try? JSONDecoder().decode(CachedPayload.self, from: stored) else { return nil }
        // Only use cache if we have a complete dataset for that day
        guard cached.isComplete else { return nil }
        guard let items = try? extractItems(cached.payload, for: region) else { return nil }
        // Validate count against expected hours (handles DST days)
        let expected = expectedHourCount(for: day)
        guard items.count == expected else { return nil }
        return items
    }

    private func saveToCache(day: Day, region: Region, payload: Data, itemsCount: Int) {
        let isComplete = itemsCount == expectedHourCount(for: day)
        let cached = CachedPayload(
            startUTC: utcInterval(for: day).start,
            isComplete: isComplete,
            payload: payload,
            fetchedAt: Date()
        )
        if let data = try? JSONEncoder().encode(cached) {
            let key = cacheKey(for: day, region: region)
            sharedDefaults.set(data, forKey: key)
        }
    }
    
    // Async/await API
    func loadFullDayData(_ day: Day, region: Region) async throws -> [PriceData] {
        // 1) Try cache first (today always, tomorrow only if complete)
        if let cached = loadFromCache(day: day, region: region) {
            return cached
        }

        // 2) Fetch from network
        let interval = utcInterval(for: day)
        guard let url = URL(string: "https://dashboard.elering.ee/api/nps/price?start=\(interval.start)&end=\(interval.end)") else {
            throw NetworkError.badURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { return [] }
        guard http.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: http.statusCode)
        }

        // 3) Decode and extract region-specific items
        let fullDayData = try extractItems(data, for: region)

        // 4) Save to cache (marked complete only when item count matches expected hours)
        saveToCache(day: day, region: region, payload: data, itemsCount: fullDayData.count)

        return fullDayData
    }
    
    // Backwards-compatible wrapper that keeps the old signature
    func loadFullDayData(_ day: Day, region: Region, completion: @escaping ([PriceData]) -> ()) {
        Task {
            let result = try? await loadFullDayData(day, region: region)
            DispatchQueue.main.async { completion(result ?? []) }
        }
    }
    
    // MARK: - Helpers
    private func utcInterval(for day: Day) -> (start: String, end: String) {
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
}


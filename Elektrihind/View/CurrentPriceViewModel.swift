//
//  CurrentPriceViewModel.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 04.04.2023.
//

import Foundation
import SwiftUI

@MainActor
class CurrentPriceViewModel: ObservableObject {
    @Published var currenPriceTimeStamp: String = "--:--"
    @Published var currenPrice: String = "---"
    @Published var unit = "---"
    private var currentPriceData: PriceData?
    private var dataLastLoaded: Date? = nil
    private var shared = Globals()
    private let network = NetworkService()
    private var updateTimer: Timer?
    
    // Aggregate 15-minute data points into hourly data points by averaging each group of 4.
    private func aggregateToHourly(_ data: [PriceData]) -> [PriceData] {
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
    
    func setup(_ shared: Globals) {
        self.shared = shared
        self.scheduleQuarterHourTimerIfNeeded()
    }
    
    func loadCurrentPrice() {
        if shouldLoadData() {
            Task {
                do {
                    let data = try await network.loadFullDayData(Day.today, region: shared.region)
                    let now = Date()
                    if self.shared.chartResolution == .oneHour {
                        // Aggregate to hourly and align to the start of the current hour
                        let hourly = self.aggregateToHourly(data)
                        let calendar = Calendar.current
                        let hourStart = calendar.dateInterval(of: .hour, for: now)?.start ?? now
                        let current = hourly.last { Date(timeIntervalSince1970: $0.timestamp) <= hourStart } ?? hourly.last
                        self.currentPriceData = current
                    } else {
                        let sorted = data.sorted { $0.timestamp < $1.timestamp }
                        let current = sorted.last { Date(timeIntervalSince1970: $0.timestamp) <= now } ?? sorted.last
                        self.currentPriceData = current
                    }
                    self.updateCurrentPrice()
                    self.dataLastLoaded = Date()
                } catch {
                    // Handle error if needed
                }
            }
        } else {
            updateCurrentPrice()
        }
    }
    
    private func shouldLoadData() -> Bool {
        if shared.todayDataUpdateMandatory {
            return true
        }

        guard let last = dataLastLoaded else {
            return true
        }

        let now = Date()
        let calendar = Calendar.current

        switch shared.chartResolution {
        case .oneHour:
            return !calendar.isDate(last, equalTo: now, toGranularity: .hour)
        case .fifteenMinutes:
            // Compute the start of the 15-minute bucket for both last and now
            func bucketStart(for date: Date) -> Date? {
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                guard let minute = comps.minute, let hour = comps.hour else { return nil }
                let flooredMinute = (minute / 15) * 15
                var dc = DateComponents()
                dc.year = comps.year
                dc.month = comps.month
                dc.day = comps.day
                dc.hour = hour
                dc.minute = flooredMinute
                dc.second = 0
                return calendar.date(from: dc)
            }
            guard let lastBucket = bucketStart(for: last), let nowBucket = bucketStart(for: now) else {
                return true
            }
            return lastBucket != nowBucket
        }
    }

    private func scheduleQuarterHourTimerIfNeeded() {
        // Invalidate any existing timer
        updateTimer?.invalidate()
        updateTimer = nil

        guard shared.chartResolution == .fifteenMinutes else { return }

        let calendar = Calendar.current
        let now = Date()
        // Compute next quarter-hour boundary
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let minute = comps.minute ?? 0
        let second = comps.second ?? 0
        let remainderMinutes = 15 - (minute % 15)
        let secondsUntilNextQuarter = TimeInterval(remainderMinutes * 60 - second)
        let fireDate = now.addingTimeInterval(max(1, secondsUntilNextQuarter))

        // Schedule a one-shot to align to the boundary, then a repeating timer every 15 minutes
        let alignTimer = Timer(fireAt: fireDate, interval: 0, target: self, selector: #selector(alignedQuarterFired), userInfo: nil, repeats: false)
        RunLoop.main.add(alignTimer, forMode: .common)
        updateTimer = alignTimer
    }

    @objc private func alignedQuarterFired() {
        // Fire immediately at the boundary
        self.loadCurrentPrice()
        // Switch to a repeating timer every 15 minutes
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            self?.loadCurrentPrice()
        }
        RunLoop.main.add(updateTimer!, forMode: .common)
    }
    
    private func updateCurrentPrice() {
        guard let data = currentPriceData else { return }
        self.getCurrentTimeStampFrom(data.timestamp)
        self.getCurrentPriceFrom(data.price)
        self.unit = self.shared.localizedString(self.shared.unit)
    }
    
    private func getCurrentTimeStampFrom(_ timeStamp: Double) {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "EET")
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = (shared.chartResolution == .oneHour) ? "HH:00" : "HH:mm"
        let date = Date(timeIntervalSince1970: timeStamp)
        self.currenPriceTimeStamp = dateFormatter.string(from: date)
    }
    
    private func getCurrentPriceFrom(_ price: Double) {
        let priceWithTax = shared.includeTax ? price * shared.taxRate : price
        let formattedPrice = shared.numberFormatter.string(from: NSNumber(value: priceWithTax / shared.divider))
        self.currenPrice = formattedPrice ?? "---"
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}


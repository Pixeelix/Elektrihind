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
    }
    
    func loadCurrentPrice() {
        if shouldLoadData() {
            Task {
                do {
                    let data = try await network.loadFullDayData(Day.today, region: shared.region)
                    let now = Date()
                    let sourceData: [PriceData]
                    if self.shared.chartResolution == .oneHour {
                        // Aggregate to hourly and align to the start of the current hour
                        let hourly = self.aggregateToHourly(data)
                        let calendar = Calendar.current
                        let hourStart = calendar.dateInterval(of: .hour, for: now)?.start ?? now
                        sourceData = hourly
                        let current = hourly.last { Date(timeIntervalSince1970: $0.timestamp) <= hourStart } ?? hourly.last
                        self.currentPriceData = current
                    } else {
                        let sorted = data.sorted { $0.timestamp < $1.timestamp }
                        let current = sorted.last { Date(timeIntervalSince1970: $0.timestamp) <= now } ?? sorted.last
                        sourceData = sorted
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
    
    private func updateCurrentPrice() {
        guard let data = currentPriceData else { return }
        self.getCurrentTimeStampFrom(data.timestamp)
        self.getCurrentPriceFrom(data.price)
        self.unit = self.shared.localizedString(self.shared.unit)
    }
    
    private func shouldLoadData() -> Bool {
        if shared.todayDataUpdateMandatory {
            return true
        }
        if let dataLastLoaded = dataLastLoaded,
           Calendar.current.isDate(dataLastLoaded, equalTo: Date(), toGranularity: .hour) {
            return false
        } else {
            return true
        }
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
}


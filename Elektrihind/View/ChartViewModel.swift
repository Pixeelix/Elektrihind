//
//  ChartViewModel.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 05.04.2023.
//

import Foundation
import SwiftUI

@MainActor
class ChartViewModel: ObservableObject {
    private var shared = Globals()
    private let network = NetworkService()
    private var day: Day = Day.today
    private var dataArrayFromAPI: [PriceData] = []
    private var dataLastLoaded: Date? = nil
    @Published var isLoading: Bool = true
    @Published var data: ChartData = TestData.data
    @Published var specifier: String = "%.1f"
    @Published var form: CGSize = ChartForm.extraLarge

    // Aggregate 15-minute data points into hourly data points by averaging each group of 4.
    private func aggregateToHourly(_ data: [PriceData]) -> [PriceData] {
        guard !data.isEmpty else { return [] }
        // Group by the hour bucket using the timestamp.
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

    func setup(_ shared: Globals, day: Day) {
        self.shared = shared
        self.day = day
        specifier = "%.\(shared.minFractionDigits)f \(shared.localizedString(shared.unit))"
    }
    
    func loadChartData() {
        if shouldLoadData() {
            isLoading = true
            Task {
                do {
                    let data = try await network.loadFullDayData(day, region: shared.region)
                    if self.day == Day.tomorrow {
                        self.shared.missingTomorrowData = data.count <= 2
                    }
                    self.dataArrayFromAPI = data
                    self.updateChartData()
                    self.dataLastLoaded = Date()
                } catch {
                    self.isLoading = false
                }
            }
        } else {
            updateChartData()
        }
    }
    
    private func updateChartData() {
        var sourceData = dataArrayFromAPI
        // If user selected hourly resolution, aggregate the 15-min data into hourly averages
        if shared.chartResolution == .oneHour {
            sourceData = aggregateToHourly(sourceData)
        }

        var fullDayChartData: [(String, Double)] = []
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "EET")
        formatter.locale = NSLocale.current
        formatter.dateFormat = shared.chartResolution == .oneHour ? "HH:00" : "HH:mm"
        for data in sourceData {
            let timeStampDate = Date(timeIntervalSince1970: data.timestamp)
            let stringTime = formatter.string(from: timeStampDate)
            let price = shared.includeTax ? (data.price / shared.divider) * shared.taxRate : data.price / shared.divider
            let dataPoint = (stringTime, price)
            fullDayChartData.append(dataPoint)
        }
        self.data = ChartData(values: fullDayChartData)
        calculateMinMaxValues()
        isLoading = false
    }
    
    private func calculateMinMaxValues() {
        var pricesArray = [Double]()
        let sourceData: [PriceData] = (shared.chartResolution == .oneHour) ? aggregateToHourly(dataArrayFromAPI) : dataArrayFromAPI
        for data in sourceData {
            let price = shared.includeTax ? data.price * shared.taxRate : data.price
            pricesArray.append(price)
        }
        let pricesSum = pricesArray.reduce(0, +)
        if let minNumberValue = pricesArray.min(),
           let maxNumberValue = pricesArray.max() {
            let minNumber = shared.numberFormatter.string(from: NSNumber(value: minNumberValue / shared.divider))
            let avgNumber = shared.numberFormatter.string(from: NSNumber(value: (pricesSum / Double(pricesArray.count)) / shared.divider))
            let maxNumber = shared.numberFormatter.string(from: NSNumber(value: maxNumberValue / shared.divider))
            if day == Day.today {
                shared.minDayPrice = minNumber ?? "---"
                shared.avgDayPrice = avgNumber ?? "---"
                shared.maxDayPrice = maxNumber ?? "---"
            } else if day == Day.tomorrow {
                shared.minNextDayPrice = minNumber ?? "---"
                shared.avgNextDayPrice = avgNumber ?? "---"
                shared.maxNextDayPrice = maxNumber ?? "---"
            }

        }
    }
    
    private func shouldLoadData() -> Bool {
        if day == Day.today && shared.todayDataUpdateMandatory {
            shared.todayDataUpdateMandatory = false
            return true
        } else if day == Day.tomorrow && shared.tomorrowDataUpdateMandatory {
            shared.tomorrowDataUpdateMandatory = false
            return true
        }
        if let dataLastLoaded = dataLastLoaded {
            if day == Day.today,
               Calendar.current.isDate(dataLastLoaded, equalTo: Date(), toGranularity: .day) {
                return false
            } else if day == Day.tomorrow && shared.missingTomorrowData {
                return true
            } else if day == Day.tomorrow && !shared.missingTomorrowData,
                      Calendar.current.isDate(dataLastLoaded, equalTo: Date(), toGranularity: .hour) {
                return false
            }
            return true
        } else {
            return true
        }
    }
}


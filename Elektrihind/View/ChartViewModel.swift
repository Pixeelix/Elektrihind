//
//  ChartViewModel.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 05.04.2023.
//

import Foundation
import SwiftUI

class ChartViewModel: ObservableObject {
    private var shared = Globals()
    private var day: Day = .today
    private var dataArrayFromAPI: [PriceData] = []
    private var dataLastLoaded: Date? = nil
    @Published var isLoading: Bool = true
    @Published var data: ChartData = TestData.data
    @Published var specifier: String = "%.1f"
    @Published var legend: String = "Quarterly"
    @Published var form: CGSize = ChartForm.extraLarge

    func setup(_ shared: Globals, day: Day) {
        self.shared = shared
        self.day = day
        specifier = "%.\(shared.minFractionDigits)f \(shared.localizedString(shared.unit))"
    }
    
    func loadChartData() {
        if shouldLoadData() {
            isLoading = true
            Network().loadFullDayData(day) { data in
                if self.day == .tomorrow {
                    self.shared.missingTomorrowData = data.count <= 2
                }
                self.dataArrayFromAPI = data
                self.updateChartData()
                self.dataLastLoaded = Date()
            }
        } else {
            updateChartData()
        }
    }
    
    private func updateChartData() {
        var fullDayChartData: [(String, Double)] = []
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "EET")
        formatter.locale = NSLocale.current
        formatter.dateFormat = "HH:mm"
        for data in dataArrayFromAPI {
            let timeStampDate = Date(timeIntervalSince1970: data.timestamp)
            let stringTime = formatter.string(from: timeStampDate)
            let price = shared.includeTax ? (data.price / shared.divider) * 1.2 : data.price / shared.divider
            let dataPoint = (stringTime, price)
            fullDayChartData.append(dataPoint)
        }
        self.data = ChartData(values: fullDayChartData)
        if day == .tomorrow {
            calculateMinMaxValues()
        }
        isLoading = false
    }
    
    private func calculateMinMaxValues() {
        var pricesArray = [Double]()
        for data in dataArrayFromAPI {
            let price = shared.includeTax ? data.price * 1.2 : data.price
            pricesArray.append(price)
        }
        if let minNumberValue = pricesArray.min(),
           let maxNumberValue = pricesArray.max() {
            let minNumber = shared.numberFormatter.string(from: NSNumber(value: minNumberValue / shared.divider))
            let maxNumber = shared.numberFormatter.string(from: NSNumber(value: maxNumberValue / shared.divider))
            shared.minNextDayPrice = minNumber ?? "---"
            shared.maxNextDayPrice = maxNumber ?? "---"
        }
    }
    
    private func shouldLoadData() -> Bool {
        if let dataLastLoaded = dataLastLoaded {
            if day == .today,
               Calendar.current.isDate(dataLastLoaded, equalTo: Date(), toGranularity: .day) {
                return false
            } else if day == .tomorrow && shared.missingTomorrowData {
                return true
            } else if day == .tomorrow && !shared.missingTomorrowData,
                      Calendar.current.isDate(dataLastLoaded, equalTo: Date(), toGranularity: .hour) {
                return false
            }
            return true
        } else {
            return true
        }
    }
}

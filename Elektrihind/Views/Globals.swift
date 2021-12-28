//
//  Globals.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 14.12.2021.
//

import Foundation

class Globals: ObservableObject {
    @Published var currentPrice: PriceData?
    @Published var todayFullDayData: [PriceData] = [] {
        didSet {
            updateFullDayData()
        }
    }
    @Published var todayFullDayChartData: [(String, Double)] = []
    @Published var nextdayFullDayData: [PriceData] = [] {
        didSet {
            nextDayPricesArray.removeAll()
            for dataPoint in nextdayFullDayData {
                nextDayPricesArray.append(dataPoint.price)
            }
        }
    }
    @Published var nextDayPricesArray: [Double] = []
    @Published var minNextDayPrice: String = ""
    @Published var maxNextDayPrice: String = ""
    @Published var divider: Double = 1
    @Published var minFractionDigits: Int = 1
    @Published var numberFormatter = NumberFormatter()
    @Published var unit: String = "€/kWh" {
        didSet {
            saveSettings()
            let formatter = NumberFormatter()
            formatter.decimalSeparator = ","
            formatter.maximumIntegerDigits = 4
            if unit == "€/kWh" {
                divider = 1000
                formatter.minimumFractionDigits = 4
            } else if unit == "€/MWh" {
                divider = 1
                formatter.minimumFractionDigits = 1
            } else if unit == "senti/kWh" {
                divider = 10
                formatter.minimumFractionDigits = 1
            }
            self.numberFormatter = formatter
            self.minFractionDigits = formatter.minimumFractionDigits
            updateFullDayData()
            calculateMinMaxValues()
        }
    }
    
    func getSavedSettings() {
        unit = UserDefaults.standard.string(forKey: "unit") ?? unit
    }
    
    func saveSettings() {
        UserDefaults.standard.set(unit, forKey: "unit")
    }
    
    func updateFullDayData() {
        todayFullDayChartData.removeAll()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "EET")
        formatter.locale = NSLocale.current
        formatter.dateFormat = "HH:mm"
        for data in todayFullDayData {
            let timeStampDate = Date(timeIntervalSince1970: data.timestamp)
            let strTime = formatter.string(from: timeStampDate)
            let dataPoint = (strTime, data.price / divider)
            todayFullDayChartData.append(dataPoint)
        }
    }
    
    func calculateMinMaxValues() {
        minNextDayPrice = numberFormatter.string(from: NSNumber(value: nextDayPricesArray.min() ?? 0 / divider)) ?? ""
        maxNextDayPrice = numberFormatter.string(from: NSNumber(value: nextDayPricesArray.max() ?? 0 / divider)) ?? ""
    }
}

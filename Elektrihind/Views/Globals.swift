//
//  Globals.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 14.12.2021.
//

import Foundation

enum Language: String {
    case estonian = "et"
    case english = "en"
    
    static let allLanguages = [estonian, english]
    var fullName: String {
      get {
        switch self {
        case .estonian:
            return "Eesti"
          case .english:
            return "English"
        }
      }
    }
}

class Globals: ObservableObject {
    @Published var currentPrice: PriceData?
    @Published var todayFullDayData: [PriceData] = [] {
        didSet {
            updateFullDayChartData()
        }
    }
    @Published var todayFullDayChartData: [(String, Double)] = []
    @Published var tomorrowFullDayData: [PriceData] = [] {
        didSet {
            updateNextDayChartData()
            calculateMinMaxValues()
        }
    }
    @Published var tomorrowFullDayChartData: [(String, Double)] = []
    @Published var minNextDayPrice: String = ""
    @Published var maxNextDayPrice: String = ""
    @Published var divider: Double = 1
    @Published var minFractionDigits: Int = 1
    @Published var numberFormatter = NumberFormatter()
    @Published var language: Language = .estonian {
        didSet {
            saveLanguage()
        }
    }
    @Published var unit: String = "€/kWh" {
        didSet {
            saveUnit()
            let formatter = NumberFormatter()
            formatter.decimalSeparator = ","
            formatter.maximumIntegerDigits = 4
            if unit == localizedString("€/kWh") {
                divider = 1000
                formatter.minimumFractionDigits = 4
            } else if unit == localizedString("€/MWh") {
                divider = 1
                formatter.minimumFractionDigits = 1
            } else if unit == localizedString("cent/kWh"){
                divider = 10
                formatter.minimumFractionDigits = 1
            }
            self.numberFormatter = formatter
            self.minFractionDigits = formatter.minimumFractionDigits
            updateFullDayChartData()
            updateNextDayChartData()
            calculateMinMaxValues()
        }
    }
    
    func getSavedSettings() {
        let languageString = UserDefaults.standard.string(forKey: "language") ?? "et"
        language = Language(rawValue: languageString) ?? .estonian
        unit = UserDefaults.standard.string(forKey: "unit") ?? unit
    }
    
    func localizedString(_ key: String) -> String {
        return key.localized(language)
    }
    
    func saveLanguage() {
        UserDefaults.standard.set(language.rawValue, forKey: "language")
        UserDefaults.standard.synchronize()
    }
    
    func saveUnit() {
        UserDefaults.standard.set(unit, forKey: "unit")
    }
    
    func updateFullDayChartData() {
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
    
    func updateNextDayChartData() {
        tomorrowFullDayChartData.removeAll()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "EET")
        formatter.locale = NSLocale.current
        formatter.dateFormat = "HH:mm"
        for data in tomorrowFullDayData {
            let timeStampDate = Date(timeIntervalSince1970: data.timestamp)
            let strTime = formatter.string(from: timeStampDate)
            let dataPoint = (strTime, data.price / divider)
            tomorrowFullDayChartData.append(dataPoint)
        }
    }
    
    func calculateMinMaxValues() {
        var pricesArray = [Double]()
        for dataPoint in tomorrowFullDayData {
            pricesArray.append(dataPoint.price)
        }
        if let minNumberValue = pricesArray.min(),
           let maxNumberValue = pricesArray.max() {
            let minNumber = numberFormatter.string(from: NSNumber(value: minNumberValue / divider))
            let maxNumber = numberFormatter.string(from: NSNumber(value: maxNumberValue / divider))
            minNextDayPrice = minNumber ?? ""
            maxNextDayPrice = maxNumber ?? ""
        }
    }
}

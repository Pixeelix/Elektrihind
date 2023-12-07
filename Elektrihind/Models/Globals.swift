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
    case finnish = "fi"
    case russian = "ru"
    
    static let allLanguages = [estonian, english, finnish, russian]
    var name: String {
      get {
        switch self {
        case .estonian:
            return "ESTONIAN"
          case .english:
            return "ENGLISH"
        case.finnish:
            return "FINNISH"
        case.russian:
            return "RUSSIAN"
        }
      }
    }
}

enum Region: String {
    case estonia = "EE"
    case latvia = "LV"
    case lithuania = "LT"
    case finland = "FI"
    
    static let allRegions = [estonia, latvia, lithuania, finland]
    var name: String {
      get {
        switch self {
        case .estonia:
            return "ESTONIA"
        case .latvia:
            return "LATVIA"
        case .lithuania:
            return "LITHUANIA"
        case .finland:
            return "FINLAND"
        }
      }
    }
}

class Globals: ObservableObject {
    @Published var missingTomorrowData = false
    @Published var minDayPrice: String = "---"
    @Published var avgDayPrice: String = "---"
    @Published var maxDayPrice: String = "---"
    @Published var minNextDayPrice: String = "---"
    @Published var avgNextDayPrice: String = "---"
    @Published var maxNextDayPrice: String = "---"
    @Published var divider: Double = 1
    @Published var minFractionDigits: Int = 1
    @Published var numberFormatter = NumberFormatter()
    @Published var todayDataUpdateMandatory: Bool = false
    @Published var tomorrowDataUpdateMandatory: Bool = false
    @Published var taxPercentage: String = "0%"
    @Published var taxRate: Double = 0.0
    @Published var includeTax: Bool = false {
        didSet {
            saveTaxValue()
        }
    }
    @Published var language: Language = .estonian {
        didSet {
            saveLanguage()
        }
    }
    @Published var region: Region = .estonia {
        didSet {
            saveRegion()
            switch region {
            case .estonia:
                taxPercentage = "20%"
                taxRate = 1.2
            case .latvia:
                taxPercentage = "21%"
                taxRate = 1.21
            case .lithuania:
                taxPercentage = "21%"
                taxRate = 1.21
            case .finland:
                taxPercentage = "24%"
                taxRate = 1.24
            }
        }
    }
    @Published var unit: String = "€/kWh" {
        didSet {
            saveUnit()
            let formatter = NumberFormatter()
            formatter.decimalSeparator = ","
            formatter.maximumIntegerDigits = 4
            if unit == "€/kWh" {
                divider = 1000
                formatter.minimumFractionDigits = 4
            } else if unit == "€/MWh" {
                divider = 1
                formatter.minimumFractionDigits = 1
            } else if unit == "cent/kWh" || unit == "senti/kWh" {
                divider = 10
                formatter.minimumFractionDigits = 1
            }
            self.numberFormatter = formatter
            self.minFractionDigits = formatter.minimumFractionDigits
        }
    }
    
    func getSavedSettings() {
        let languageString = UserDefaults.standard.string(forKey: "language") ?? getLanguageFromLocale()
        language = Language(rawValue: languageString) ?? .estonian
        let regionString = UserDefaults.standard.string(forKey: "region") ?? getRegionFromLocale()
        region = Region(rawValue: regionString) ?? .estonia
        unit = UserDefaults.standard.string(forKey: "unit") ?? unit
        includeTax = UserDefaults.standard.bool(forKey: "includeTax")
    }
    
    private func getLanguageFromLocale() -> String {
        if let regionCode = Locale.current.regionCode {
            switch regionCode {
            case "EE":
                return "et"
            case "FI":
                return "fi"
            case "RU":
                return "ru"
            default:
                return "et"
            }
        } else {
            return "en"
        }
    }
    
    private func getRegionFromLocale() -> String {
        if let regionCode = Locale.current.regionCode {
            return regionCode
        } else {
            return "EE"
        }
    }
    
    func localizedString(_ key: String) -> String {
        return key.localized(language)
    }
    
    func saveLanguage() {
        UserDefaults.standard.set(language.rawValue, forKey: "language")
        UserDefaults.standard.synchronize()
    }
    
    func saveRegion() {
        UserDefaults.standard.set(region.rawValue, forKey: "region")
        UserDefaults.standard.synchronize()
    }
    
    func saveUnit() {
        UserDefaults.standard.set(unit, forKey: "unit")
    }
    
    func saveTaxValue() {
        UserDefaults.standard.set(includeTax, forKey: "includeTax")
    }
}

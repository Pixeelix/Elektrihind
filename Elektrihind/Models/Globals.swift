//
//  Globals.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 14.12.2021.
//

import Foundation
import SwiftUI
import WidgetKit

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

enum ChartResolution: String, CaseIterable, Hashable {
    case fifteenMinutes = "15min"
    case oneHour = "1h"

    var label: String {
        switch self {
        case .fifteenMinutes: return "15 min"
        case .oneHour: return "1 h"
        }
    }
}

class Globals: ObservableObject {
    
    private let appGroupID = "group.koodipardik.Elektrihind"
    private var appGroupDefaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    private func mirrorToAppGroup(key: String, value: Any) {
        guard let defaults = appGroupDefaults else { return }
        defaults.set(value, forKey: key)
    }
    
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
                taxPercentage = "24%"
                taxRate = 1.24
            case .latvia:
                taxPercentage = "21%"
                taxRate = 1.21
            case .lithuania:
                taxPercentage = "21%"
                taxRate = 1.21
            case .finland:
                taxPercentage = "25,5%"
                taxRate = 1.255
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
    
    @Published var chartResolution: ChartResolution = {
        if let saved = UserDefaults.standard.string(forKey: "chartResolution"),
           let value = ChartResolution(rawValue: saved) {
            return value
        }
        return .fifteenMinutes
    }() {
        didSet {
            saveChartResolution()
        }
    }
    
    // New property for "Always On Display"
     @Published var alwaysOnDisplay: Bool = UserDefaults.standard.bool(forKey: "alwaysOnDisplay") {
         didSet {
             saveAlwaysOnDisplay()
             UIApplication.shared.isIdleTimerDisabled = alwaysOnDisplay
         }
     }
    
    func getSavedSettings() {
        let languageString = UserDefaults.standard.string(forKey: "language") ?? getLanguageFromLocale()
        language = Language(rawValue: languageString) ?? .estonian
        let regionString = UserDefaults.standard.string(forKey: "region") ?? getRegionFromLocale()
        region = Region(rawValue: regionString) ?? .estonia
        unit = UserDefaults.standard.string(forKey: "unit") ?? unit
        includeTax = UserDefaults.standard.bool(forKey: "includeTax")
        alwaysOnDisplay = UserDefaults.standard.bool(forKey: "alwaysOnDisplay")
        UIApplication.shared.isIdleTimerDisabled = alwaysOnDisplay
        
        if let savedResolution = UserDefaults.standard.string(forKey: "chartResolution"),
           let value = ChartResolution(rawValue: savedResolution) {
            chartResolution = value
        }
        
        // Mirror values to App Group so the widget can read them
        mirrorToAppGroup(key: "language", value: language.rawValue)
        mirrorToAppGroup(key: "region", value: region.rawValue)
        mirrorToAppGroup(key: "unit", value: unit)
        mirrorToAppGroup(key: "includeTax", value: includeTax)
        mirrorToAppGroup(key: "chartResolution", value: chartResolution.rawValue)
    }
    
    private func getLanguageFromLocale() -> String {
        if let regionCode = Locale.current.region?.identifier {
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
        if let regionCode = Locale.current.region?.identifier {
            return regionCode
        } else {
            return "EE"
        }
    }
    
    func localizedString(_ key: String) -> String {
        return key.localized(language, in: .main)
    }
    
    func saveLanguage() {
        UserDefaults.standard.set(language.rawValue, forKey: "language")
        mirrorToAppGroup(key: "language", value: language.rawValue)
        WidgetCenter.shared.reloadAllTimelines()
        UserDefaults.standard.synchronize()
    }
    
    func saveRegion() {
        UserDefaults.standard.set(region.rawValue, forKey: "region")
        mirrorToAppGroup(key: "region", value: region.rawValue)
        WidgetCenter.shared.reloadAllTimelines()
        UserDefaults.standard.synchronize()
    }
    
    func saveUnit() {
        UserDefaults.standard.set(unit, forKey: "unit")
        mirrorToAppGroup(key: "unit", value: unit)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func saveTaxValue() {
        UserDefaults.standard.set(includeTax, forKey: "includeTax")
        mirrorToAppGroup(key: "includeTax", value: includeTax)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func saveAlwaysOnDisplay() {
        UserDefaults.standard.set(alwaysOnDisplay, forKey: "alwaysOnDisplay")
    }
    
    func saveChartResolution() {
        UserDefaults.standard.set(chartResolution.rawValue, forKey: "chartResolution")
        mirrorToAppGroup(key: "chartResolution", value: chartResolution.rawValue)
        WidgetCenter.shared.reloadAllTimelines()
    }
}


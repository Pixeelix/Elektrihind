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
    @Published var missingTomorrowData = false
    @Published var minNextDayPrice: String = "---"
    @Published var maxNextDayPrice: String = "---"
    @Published var divider: Double = 1
    @Published var minFractionDigits: Int = 1
    @Published var numberFormatter = NumberFormatter()
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
        let languageString = UserDefaults.standard.string(forKey: "language") ?? "et"
        language = Language(rawValue: languageString) ?? .estonian
        unit = UserDefaults.standard.string(forKey: "unit") ?? unit
        includeTax = UserDefaults.standard.bool(forKey: "includeTax")
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
    
    func saveTaxValue() {
        UserDefaults.standard.set(includeTax, forKey: "includeTax")
    }
}

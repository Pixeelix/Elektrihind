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
    case russian = "ru"
    
    static let allLanguages = [estonian, english, russian]
}

class Globals: ObservableObject {
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
            numberFormatter.decimalSeparator = ","
            numberFormatter.maximumIntegerDigits = 4
            if unit == "€/kWh" {
                divider = 1000
                minFractionDigits = 4
            } else if unit == "€/MWh" {
                divider = 1
                minFractionDigits = 1
            } else if unit == "senti/kWh" {
                divider = 10
                minFractionDigits = 1
            }
            numberFormatter.minimumFractionDigits = minFractionDigits
        }
    }
    
    init() {
        getSavedSettings()
    }
    
    func getSavedSettings() {
        let languageString = UserDefaults.standard.string(forKey: "language") ?? "et"
        language = Language(rawValue: languageString) ?? .estonian
        unit = UserDefaults.standard.string(forKey: "unit") ?? unit
    }
    
    func saveLanguage() {
        UserDefaults.standard.set(language.rawValue, forKey: "language")
    }
    
    func saveUnit() {
        UserDefaults.standard.set(unit, forKey: "unit")
    }
}

//
//  Globals.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 14.12.2021.
//

import Foundation

class Globals: ObservableObject {
    @Published var currentPrice: PriceData?
    @Published var todayFullDayData: Array<PriceData> = []
    @Published var divider: Double = 1
    @Published var minFractionDigits: Int = 1
    @Published var numberFormatter = NumberFormatter()
    @Published var unit: String = "€/kWh" {
        didSet {
            saveSettings()
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
    
    func getSavedSettings() {
        unit = UserDefaults.standard.string(forKey: "unit") ?? unit
    }
    
    func saveSettings() {
        UserDefaults.standard.set(unit, forKey: "unit")
    }
}

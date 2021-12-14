//
//  Globals.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 14.12.2021.
//

import Foundation

class Globals: ObservableObject {
    @Published var unit: String = "€/kWh" {
        didSet {
            saveSettings()
        }
    }
    
    init() {
        getSavedSettings()
    }
    
    func getSavedSettings() {
        unit = UserDefaults.standard.string(forKey: "unit") ?? unit
    }
    
    func saveSettings() {
        UserDefaults.standard.set(unit, forKey: "unit")
    }
}

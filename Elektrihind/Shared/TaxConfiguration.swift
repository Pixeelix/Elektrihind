//
//  TaxConfiguration.swift
//  NordPrice
//
//  Shared tax rate configuration for all regions.
//

import Foundation

enum TaxConfiguration {
    /// Returns the tax multiplier for a region (e.g. 1.24 for 24% VAT).
    static func taxRate(for region: Region) -> Double {
        switch region {
        case .estonia: return 1.24
        case .latvia: return 1.21
        case .lithuania: return 1.21
        case .finland: return 1.255
        }
    }

    /// Returns the tax multiplier for a region code string (e.g. "EE").
    static func taxRate(forCode regionCode: String) -> Double {
        switch regionCode.uppercased() {
        case "EE": return 1.24
        case "LV": return 1.21
        case "LT": return 1.21
        case "FI": return 1.255
        default: return 1.24
        }
    }

    /// Returns a display string for the tax percentage.
    static func taxPercentage(for region: Region) -> String {
        switch region {
        case .estonia: return "24%"
        case .latvia: return "21%"
        case .lithuania: return "21%"
        case .finland: return "25,5%"
        }
    }
}

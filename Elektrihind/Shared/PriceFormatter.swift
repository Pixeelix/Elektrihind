//
//  PriceFormatter.swift
//  Elektrihind
//
//  Shared price formatting configuration.
//

import Foundation

enum PriceFormatter {
    /// Returns a configured NumberFormatter and the price divider for a given unit string.
    static func formatter(for unit: String) -> (formatter: NumberFormatter, divider: Double, minFractionDigits: Int) {
        let formatter = NumberFormatter()
        formatter.decimalSeparator = ","
        formatter.maximumIntegerDigits = 4
        let divider: Double
        if unit == "€/kWh" {
            divider = 1000
            formatter.minimumFractionDigits = 4
        } else if unit == "€/MWh" {
            divider = 1
            formatter.minimumFractionDigits = 1
        } else if unit == "cent/kWh" || unit == "senti/kWh" {
            divider = 10
            formatter.minimumFractionDigits = 1
        } else {
            divider = 1000
            formatter.minimumFractionDigits = 4
        }
        return (formatter, divider, formatter.minimumFractionDigits)
    }
}

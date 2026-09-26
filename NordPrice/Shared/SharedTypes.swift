//
//  SharedTypes.swift
//  NordPrice
//
//  Shared type definitions used by both app and widget targets.
//

import Foundation
import SwiftUI

enum Day {
    case today
    case tomorrow
}

enum Region: String {
    case estonia = "EE" 
    case latvia = "LV"
    case lithuania = "LT"
    case finland = "FI"

    static let allRegions = [estonia, latvia, lithuania, finland]
    var name: String {
        switch self {
        case .estonia: return "ESTONIA"
        case .latvia: return "LATVIA"
        case .lithuania: return "LITHUANIA"
        case .finland: return "FINLAND"
        }
    }
}

enum ChartType: String, CaseIterable, Hashable {
    case bar = "bar"
    case line = "line"

    var systemImage: String {
        switch self {
        case .bar: return "chart.bar.fill"
        case .line: return "chart.xyaxis.line"
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

/// Absolute price level, shared with the website (nordprice landing page) so a
/// "cheap" bar in the app and a "Cheap" badge on the web mean the same thing.
/// Thresholds are in raw Nord Pool €/MWh (5 / 10 / 20 c/kWh) and are applied to
/// the price *before* unit conversion and VAT, so colors stay stable when the
/// user toggles units or tax.
enum PriceLevel: CaseIterable {
    case veryCheap
    case cheap
    case normal
    case expensive

    static let cheapUpperMWh: Double = 50
    static let normalUpperMWh: Double = 100
    static let expensiveLowerMWh: Double = 200

    init(rawMWh: Double) {
        if rawMWh < Self.cheapUpperMWh {
            self = .veryCheap
        } else if rawMWh < Self.normalUpperMWh {
            self = .cheap
        } else if rawMWh < Self.expensiveLowerMWh {
            self = .normal
        } else {
            self = .expensive
        }
    }

    var localizationKey: String {
        switch self {
        case .veryCheap: return "LEVEL_VERY_CHEAP"
        case .cheap: return "LEVEL_CHEAP"
        case .normal: return "LEVEL_NORMAL"
        case .expensive: return "LEVEL_EXPENSIVE"
        }
    }

    /// Same hues as the website (emerald / brand blue / amber / rose). Emerald
    /// and rose differ in luminance, so the scale stays readable for red-green
    /// color blindness.
    var color: Color {
        switch self {
        case .veryCheap: return Color(red: 16/255, green: 185/255, blue: 129/255)   // #10B981
        case .cheap: return Color(red: 92/255, green: 110/255, blue: 245/255)      // #5C6EF5
        case .normal: return Color(red: 245/255, green: 158/255, blue: 11/255)     // #F59E0B
        case .expensive: return Color(red: 244/255, green: 63/255, blue: 94/255)   // #F43F5E
        }
    }
}

//
//  SharedTypes.swift
//  Elektrihind
//
//  Shared type definitions used by both app and widget targets.
//

import Foundation

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

//
//  TimeZoneHelper.swift
//  NordPrice
//
//  Region-aware timezone using IANA identifiers (handles DST correctly).
//

import Foundation

enum TimeZoneHelper {
    /// Returns the correct IANA timezone for a Region enum value.
    static func timeZone(for region: Region) -> TimeZone {
        switch region {
        case .estonia: return TimeZone(identifier: "Europe/Tallinn") ?? .current
        case .latvia: return TimeZone(identifier: "Europe/Riga") ?? .current
        case .lithuania: return TimeZone(identifier: "Europe/Vilnius") ?? .current
        case .finland: return TimeZone(identifier: "Europe/Helsinki") ?? .current
        }
    }

    /// Returns the correct IANA timezone for a region code string (e.g. "EE").
    static func timeZone(forCode regionCode: String) -> TimeZone {
        switch regionCode.uppercased() {
        case "EE": return TimeZone(identifier: "Europe/Tallinn") ?? .current
        case "LV": return TimeZone(identifier: "Europe/Riga") ?? .current
        case "LT": return TimeZone(identifier: "Europe/Vilnius") ?? .current
        case "FI": return TimeZone(identifier: "Europe/Helsinki") ?? .current
        default: return .current
        }
    }
}

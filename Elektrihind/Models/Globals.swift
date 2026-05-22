//
//  Globals.swift
//  NordPrice
//
//  Created by Martin Pihooja on 14.12.2021.
//

import Foundation
import SwiftUI
import WidgetKit

class AppSettings: ObservableObject {

    private let appGroupID = "group.koodipardik.Elektrihind"
    private var appGroupDefaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }
    private var isLoadingSavedSettings = false

    private func mirrorToAppGroup(key: String, value: Any) {
        guard let defaults = appGroupDefaults else { return }
        defaults.set(value, forKey: key)
    }

    @Published var divider: Double = 1
    @Published var minFractionDigits: Int = 1
    @Published var numberFormatter = NumberFormatter()
    @Published var todayDataUpdateMandatory: Bool = false
    @Published var tomorrowDataUpdateMandatory: Bool = false

    var taxPercentage: String {
        TaxConfiguration.taxPercentage(for: region)
    }

    var taxRate: Double {
        TaxConfiguration.taxRate(for: region)
    }

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
        }
    }
    @Published var unit: String = "€/kWh" {
        didSet {
            saveUnit()
            let config = PriceFormatter.formatter(for: unit)
            self.divider = config.divider
            self.numberFormatter = config.formatter
            self.minFractionDigits = config.minFractionDigits
        }
    }

    @Published var chartType: ChartType = {
        if let saved = UserDefaults.standard.string(forKey: "chartType"),
           let value = ChartType(rawValue: saved) {
            return value
        }
        return .bar
    }() {
        didSet {
            saveChartType()
        }
    }

    @Published var chartResolution: ChartResolution = {
        if let saved = UserDefaults.standard.string(forKey: "chartResolution"),
           let value = ChartResolution(rawValue: saved) {
            return value
        }
        return .oneHour
    }() {
        didSet {
            saveChartResolution()
        }
    }

    @Published var alwaysOnDisplay: Bool = UserDefaults.standard.bool(forKey: "alwaysOnDisplay") {
        didSet {
            saveAlwaysOnDisplay()
            UIApplication.shared.isIdleTimerDisabled = alwaysOnDisplay
        }
    }

    @Published var notifyMaxEnabled: Bool = false {
        didSet { saveNotifyMaxEnabled() }
    }
    @Published var notifyMaxRawMWh: Double = 200 {
        didSet { saveNotifyMaxRawMWh() }
    }
    @Published var notifyMinEnabled: Bool = false {
        didSet { saveNotifyMinEnabled() }
    }
    @Published var notifyMinRawMWh: Double = 0 {
        didSet { saveNotifyMinRawMWh() }
    }

    var notifyMaxDisplay: Double {
        get { (notifyMaxRawMWh * (includeTax ? taxRate : 1)) / divider }
        set { notifyMaxRawMWh = (newValue * divider) / (includeTax ? taxRate : 1) }
    }
    var notifyMinDisplay: Double {
        get { (notifyMinRawMWh * (includeTax ? taxRate : 1)) / divider }
        set { notifyMinRawMWh = (newValue * divider) / (includeTax ? taxRate : 1) }
    }

    func getSavedSettings() {
        isLoadingSavedSettings = true
        defer {
            isLoadingSavedSettings = false
            syncRemoteNotificationPreferences()
        }

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

        if let savedChartType = UserDefaults.standard.string(forKey: "chartType"),
           let value = ChartType(rawValue: savedChartType) {
            chartType = value
        }

        UserDefaults.standard.register(defaults: ["notifyMaxRawMWh": 200.0, "notifyMinRawMWh": 0.0])
        notifyMaxEnabled = UserDefaults.standard.bool(forKey: "notifyMaxEnabled")
        if UserDefaults.standard.object(forKey: "notifyMaxRawMWh") != nil {
            notifyMaxRawMWh = UserDefaults.standard.double(forKey: "notifyMaxRawMWh")
        }
        notifyMinEnabled = UserDefaults.standard.bool(forKey: "notifyMinEnabled")
        if UserDefaults.standard.object(forKey: "notifyMinRawMWh") != nil {
            notifyMinRawMWh = UserDefaults.standard.double(forKey: "notifyMinRawMWh")
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

    func syncRemoteNotificationPreferences() {
        NotificationService.shared.syncRemoteSettings(settings: self)
    }

    private func syncRemoteNotificationPreferencesAfterChange() {
        guard !isLoadingSavedSettings else { return }
        syncRemoteNotificationPreferences()
    }

    func saveLanguage() {
        UserDefaults.standard.set(language.rawValue, forKey: "language")
        mirrorToAppGroup(key: "language", value: language.rawValue)
        WidgetCenter.shared.reloadAllTimelines()
        UserDefaults.standard.synchronize()
        syncRemoteNotificationPreferencesAfterChange()
    }

    func saveRegion() {
        UserDefaults.standard.set(region.rawValue, forKey: "region")
        mirrorToAppGroup(key: "region", value: region.rawValue)
        WidgetCenter.shared.reloadAllTimelines()
        UserDefaults.standard.synchronize()
        syncRemoteNotificationPreferencesAfterChange()
    }

    func saveUnit() {
        UserDefaults.standard.set(unit, forKey: "unit")
        mirrorToAppGroup(key: "unit", value: unit)
        WidgetCenter.shared.reloadAllTimelines()
        syncRemoteNotificationPreferencesAfterChange()
    }

    func saveTaxValue() {
        UserDefaults.standard.set(includeTax, forKey: "includeTax")
        mirrorToAppGroup(key: "includeTax", value: includeTax)
        WidgetCenter.shared.reloadAllTimelines()
        syncRemoteNotificationPreferencesAfterChange()
    }

    func saveAlwaysOnDisplay() {
        UserDefaults.standard.set(alwaysOnDisplay, forKey: "alwaysOnDisplay")
    }

    func saveNotifyMaxEnabled() {
        UserDefaults.standard.set(notifyMaxEnabled, forKey: "notifyMaxEnabled")
        syncRemoteNotificationPreferencesAfterChange()
    }

    func saveNotifyMaxRawMWh() {
        UserDefaults.standard.set(notifyMaxRawMWh, forKey: "notifyMaxRawMWh")
        syncRemoteNotificationPreferencesAfterChange()
    }

    func saveNotifyMinEnabled() {
        UserDefaults.standard.set(notifyMinEnabled, forKey: "notifyMinEnabled")
        syncRemoteNotificationPreferencesAfterChange()
    }

    func saveNotifyMinRawMWh() {
        UserDefaults.standard.set(notifyMinRawMWh, forKey: "notifyMinRawMWh")
        syncRemoteNotificationPreferencesAfterChange()
    }

    func saveChartType() {
        UserDefaults.standard.set(chartType.rawValue, forKey: "chartType")
    }

    func saveChartResolution() {
        UserDefaults.standard.set(chartResolution.rawValue, forKey: "chartResolution")
        mirrorToAppGroup(key: "chartResolution", value: chartResolution.rawValue)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// Backwards compatibility typealias during migration
typealias Globals = AppSettings

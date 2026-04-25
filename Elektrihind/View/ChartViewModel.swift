//
//  ChartViewModel.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 05.04.2023.
//

import Foundation
import SwiftUI
import Combine

struct PriceChartEntry: Identifiable {
    let id: Int
    let timeLabel: String
    let price: Double
    let isCurrent: Bool
}

@MainActor
class ChartViewModel: ObservableObject {
    private var settings: AppSettings?
    private let network = NetworkService()
    private var day: Day = Day.today
    private var dataArrayFromAPI: [PriceData] = []
    private var dataLastLoaded: Date? = nil
    private var isConfigured = false
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?

    @Published var isLoading: Bool = true
    @Published var data: ChartData = TestData.data
    @Published var specifier: String = "%.1f"
    @Published var form: CGSize = ChartForm.extraLarge
    @Published var minPrice: String = "---"
    @Published var avgPrice: String = "---"
    @Published var maxPrice: String = "---"
    @Published var missingData: Bool = false
    @Published var errorMessage: String? = nil

    var chartEntries: [PriceChartEntry] {
        let points = data.points
        guard !points.isEmpty else { return [] }

        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let minute = Calendar.current.component(.minute, from: now)
        let minutesIntoDay = hour * 60 + minute
        let totalPoints = points.count

        return points.enumerated().map { index, point in
            var isCurrent = false
            if day == .today && totalPoints > 0 {
                let proportionOfDay = Double(minutesIntoDay) / (24.0 * 60.0)
                let currentIndex = min(totalPoints - 1, max(0, Int(floor(Double(totalPoints) * proportionOfDay))))
                isCurrent = (index == currentIndex)
            }
            return PriceChartEntry(id: index, timeLabel: point.0, price: point.1, isCurrent: isCurrent)
        }
    }

    func configure(settings: AppSettings, day: Day) {
        self.settings = settings
        self.day = day
        updateSpecifier()

        if !isConfigured {
            isConfigured = true
            observeSettingsChanges()
            loadChartData()
        }
    }

    private func updateSpecifier() {
        guard let settings = settings else { return }
        specifier = "%.\(settings.minFractionDigits)f \(settings.localizedString(settings.unit))"
    }

    private func observeSettingsChanges() {
        guard let settings = settings else { return }

        settings.$chartResolution
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.settings?.todayDataUpdateMandatory = true
                self?.settings?.tomorrowDataUpdateMandatory = true
                self?.updateSpecifier()
                self?.loadChartData()
            }
            .store(in: &cancellables)

        settings.$region
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.settings?.todayDataUpdateMandatory = true
                self?.settings?.tomorrowDataUpdateMandatory = true
                self?.loadChartData()
            }
            .store(in: &cancellables)

        settings.$unit
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateSpecifier()
                self?.updateChartData()
            }
            .store(in: &cancellables)

        settings.$includeTax
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateChartData()
            }
            .store(in: &cancellables)
    }

    func loadChartData() {
        guard let settings = settings else { return }
        if shouldLoadData() {
            isLoading = true
            loadTask?.cancel()
            loadTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let data = try await network.loadFullDayData(day, region: settings.region)
                    if self.day == Day.tomorrow {
                        self.missingData = data.count <= 4
                    }
                    self.dataArrayFromAPI = data
                    self.updateChartData()
                    self.dataLastLoaded = Date()
                } catch {
                    self.isLoading = false
                    let urlError = error as? URLError
                    if !(error is CancellationError) && urlError?.code != .cancelled {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            updateChartData()
        }
    }

    func cancelInFlight() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }

    private func updateChartData() {
        guard let settings = settings else { return }
        var sourceData = dataArrayFromAPI
        if settings.chartResolution == .oneHour {
            sourceData = PriceUtilities.aggregateToHourly(sourceData)
        }

        var fullDayChartData: [(String, Double)] = []
        let formatter = DateFormatter()
        formatter.timeZone = TimeZoneHelper.timeZone(for: settings.region)
        formatter.locale = NSLocale.current
        formatter.dateFormat = settings.chartResolution == .oneHour ? "HH:00" : "HH:mm"
        for data in sourceData {
            let timeStampDate = Date(timeIntervalSince1970: data.timestamp)
            let stringTime = formatter.string(from: timeStampDate)
            let price = settings.includeTax ? (data.price / settings.divider) * settings.taxRate : data.price / settings.divider
            let dataPoint = (stringTime, price)
            fullDayChartData.append(dataPoint)
        }
        self.data = ChartData(values: fullDayChartData)
        calculateMinMaxValues()
        isLoading = false
    }

    private func calculateMinMaxValues() {
        guard let settings = settings else { return }
        var pricesArray = [Double]()
        let sourceData: [PriceData] = (settings.chartResolution == .oneHour) ? PriceUtilities.aggregateToHourly(dataArrayFromAPI) : dataArrayFromAPI
        for data in sourceData {
            let price = settings.includeTax ? data.price * settings.taxRate : data.price
            pricesArray.append(price)
        }
        let pricesSum = pricesArray.reduce(0, +)
        if let minNumberValue = pricesArray.min(),
           let maxNumberValue = pricesArray.max() {
            let minNumber = settings.numberFormatter.string(from: NSNumber(value: minNumberValue / settings.divider))
            let avgNumber = settings.numberFormatter.string(from: NSNumber(value: (pricesSum / Double(pricesArray.count)) / settings.divider))
            let maxNumber = settings.numberFormatter.string(from: NSNumber(value: maxNumberValue / settings.divider))
            self.minPrice = minNumber ?? "---"
            self.avgPrice = avgNumber ?? "---"
            self.maxPrice = maxNumber ?? "---"
        }
    }

    private func shouldLoadData() -> Bool {
        guard let settings = settings else { return true }
        if day == Day.today && settings.todayDataUpdateMandatory {
            settings.todayDataUpdateMandatory = false
            return true
        } else if day == Day.tomorrow && settings.tomorrowDataUpdateMandatory {
            settings.tomorrowDataUpdateMandatory = false
            return true
        }
        if let dataLastLoaded = dataLastLoaded {
            if day == Day.today,
               Calendar.current.isDate(dataLastLoaded, equalTo: Date(), toGranularity: .day) {
                return false
            } else if day == Day.tomorrow && missingData {
                return true
            } else if day == Day.tomorrow && !missingData,
                      Calendar.current.isDate(dataLastLoaded, equalTo: Date(), toGranularity: .hour) {
                return false
            }
            return true
        } else {
            return true
        }
    }
}

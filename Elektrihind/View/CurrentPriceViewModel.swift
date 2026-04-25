//
//  CurrentPriceViewModel.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 04.04.2023.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class CurrentPriceViewModel: ObservableObject {
    @Published var currentPriceTimestamp: String = "--:--"
    @Published var currentPrice: String = "---"
    @Published var unit = "---"
    @Published var errorMessage: String? = nil
    private var currentPriceData: PriceData?
    private var dataLastLoaded: Date? = nil
    private var settings: AppSettings?
    private let network = NetworkService()
    private var timerTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var isConfigured = false
    private var cancellables = Set<AnyCancellable>()

    func configure(settings: AppSettings) {
        self.settings = settings

        if !isConfigured {
            isConfigured = true
            observeSettingsChanges()
            scheduleQuarterHourTimerIfNeeded()
            loadCurrentPrice()
        }
    }

    private func observeSettingsChanges() {
        guard let settings = settings else { return }

        settings.$chartResolution
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleQuarterHourTimerIfNeeded()
                self?.loadCurrentPrice()
            }
            .store(in: &cancellables)

        settings.$region
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadCurrentPrice()
            }
            .store(in: &cancellables)

        Publishers.Merge(
            settings.$unit.dropFirst().map { _ in () },
            settings.$includeTax.dropFirst().map { _ in () }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] in
            self?.updateCurrentPrice()
        }
        .store(in: &cancellables)
    }

    func loadCurrentPrice() {
        guard let settings = settings else { return }
        if shouldLoadData() {
            loadTask?.cancel()
            loadTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let data = try await network.loadFullDayData(Day.today, region: settings.region)
                    let now = Date()
                    if settings.chartResolution == .oneHour {
                        let hourly = PriceUtilities.aggregateToHourly(data)
                        let calendar = Calendar.current
                        let hourStart = calendar.dateInterval(of: .hour, for: now)?.start ?? now
                        let current = hourly.last { Date(timeIntervalSince1970: $0.timestamp) <= hourStart } ?? hourly.last
                        self.currentPriceData = current
                    } else {
                        let sorted = data.sorted { $0.timestamp < $1.timestamp }
                        let current = sorted.last { Date(timeIntervalSince1970: $0.timestamp) <= now } ?? sorted.last
                        self.currentPriceData = current
                    }
                    self.updateCurrentPrice()
                    self.dataLastLoaded = Date()
                } catch {
                    let urlError = error as? URLError
                    if !(error is CancellationError) && urlError?.code != .cancelled {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            updateCurrentPrice()
        }
    }

    func cancelInFlight() {
        loadTask?.cancel()
        loadTask = nil
    }

    private func shouldLoadData() -> Bool {
        guard let settings = settings else { return true }
        if settings.todayDataUpdateMandatory {
            return true
        }

        guard let last = dataLastLoaded else {
            return true
        }

        let now = Date()
        let calendar = Calendar.current

        switch settings.chartResolution {
        case .oneHour:
            return !calendar.isDate(last, equalTo: now, toGranularity: .hour)
        case .fifteenMinutes:
            func bucketStart(for date: Date) -> Date? {
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                guard let minute = comps.minute, let hour = comps.hour else { return nil }
                let flooredMinute = (minute / 15) * 15
                var dc = DateComponents()
                dc.year = comps.year
                dc.month = comps.month
                dc.day = comps.day
                dc.hour = hour
                dc.minute = flooredMinute
                dc.second = 0
                return calendar.date(from: dc)
            }
            guard let lastBucket = bucketStart(for: last), let nowBucket = bucketStart(for: now) else {
                return true
            }
            return lastBucket != nowBucket
        }
    }

    private func scheduleQuarterHourTimerIfNeeded() {
        guard let settings = settings else { return }
        timerTask?.cancel()
        timerTask = nil

        guard settings.chartResolution == .fifteenMinutes else { return }

        timerTask = Task { [weak self] in
            let calendar = Calendar.current
            let now = Date()
            let comps = calendar.dateComponents([.minute, .second], from: now)
            let minute = comps.minute ?? 0
            let second = comps.second ?? 0
            let remainderMinutes = 15 - (minute % 15)
            let secondsUntilNextQuarter = UInt64(max(1, remainderMinutes * 60 - second))

            try? await Task.sleep(nanoseconds: secondsUntilNextQuarter * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.loadCurrentPrice()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15 * 60 * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.loadCurrentPrice()
            }
        }
    }

    private func updateCurrentPrice() {
        guard let settings = settings, let data = currentPriceData else { return }
        self.getCurrentTimeStampFrom(data.timestamp)
        self.getCurrentPriceFrom(data.price)
        self.unit = settings.localizedString(settings.unit)
    }

    private func getCurrentTimeStampFrom(_ timeStamp: Double) {
        guard let settings = settings else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZoneHelper.timeZone(for: settings.region)
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = (settings.chartResolution == .oneHour) ? "HH:00" : "HH:mm"
        let date = Date(timeIntervalSince1970: timeStamp)
        self.currentPriceTimestamp = dateFormatter.string(from: date)
    }

    private func getCurrentPriceFrom(_ price: Double) {
        guard let settings = settings else { return }
        let priceWithTax = settings.includeTax ? price * settings.taxRate : price
        let formattedPrice = settings.numberFormatter.string(from: NSNumber(value: priceWithTax / settings.divider))
        self.currentPrice = formattedPrice ?? "---"
    }

    deinit {
        timerTask?.cancel()
        loadTask?.cancel()
    }
}

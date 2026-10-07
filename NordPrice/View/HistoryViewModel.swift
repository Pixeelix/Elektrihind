//
//  HistoryViewModel.swift
//  NordPrice
//
//  Price history: one bar per day (week, month) or per month (year), moving
//  through calendar periods one at a time.
//

import Foundation

enum HistoryPeriod: String, CaseIterable, Hashable {
    case week
    case month
    case year

    var localizationKey: String {
        switch self {
        case .week: return "PERIOD_WEEK"
        case .month: return "PERIOD_MONTH"
        case .year: return "PERIOD_YEAR"
        }
    }

    fileprivate var calendarComponent: Calendar.Component {
        switch self {
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
}

/// One bar of the history chart. `rawPriceMWh` is nil for slots without data
/// (days still ahead in the current period, or before Elering's data begins).
struct HistoryBar: Identifiable {
    let id: Int
    let start: Date
    let rawPriceMWh: Double?

    var level: PriceLevel? {
        rawPriceMWh.map { PriceLevel(rawMWh: $0) }
    }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var period: HistoryPeriod = .month {
        didSet {
            // The anchor stays put: from "September" to "Year" shows the year
            // containing September.
            guard period != oldValue else { return }
            load()
        }
    }
    @Published private(set) var anchor = Date()
    @Published private(set) var bars: [HistoryBar] = []
    @Published private(set) var isLoading = true
    @Published private(set) var loadFailed = false

    private var region: Region = .estonia
    private var isConfigured = false
    private var loadTask: Task<Void, Never>?
    private var calendar: Calendar { HistoryCalendar.calendar }

    var interval: DateInterval {
        calendar.dateInterval(of: period.calendarComponent, for: anchor)
            ?? DateInterval(start: calendar.startOfDay(for: anchor), duration: 24 * 3600)
    }

    var canGoBack: Bool { interval.start > HistoryCalendar.earliestDate }
    var canGoForward: Bool { interval.end <= Date() }

    /// Bars that have data.
    private var pricedBars: [(bar: HistoryBar, price: Double)] {
        bars.compactMap { bar in bar.rawPriceMWh.map { (bar, $0) } }
    }

    var hasData: Bool { !pricedBars.isEmpty }
    var averageRawMWh: Double? {
        let prices = pricedBars.map(\.price)
        return prices.isEmpty ? nil : prices.reduce(0, +) / Double(prices.count)
    }
    var cheapestBar: HistoryBar? { pricedBars.min { $0.price < $1.price }?.bar }
    var mostExpensiveBar: HistoryBar? { pricedBars.max { $0.price < $1.price }?.bar }

    func configure(region: Region) {
        guard !isConfigured || region != self.region else { return }
        isConfigured = true
        self.region = region
        load()
    }

    func goBack() { move(by: -1) }
    func goForward() { move(by: 1) }

    private func move(by value: Int) {
        guard let newAnchor = calendar.date(byAdding: period.calendarComponent, value: value, to: anchor) else { return }
        anchor = min(newAnchor, Date())
        load()
    }

    /// Jump to the period containing `date` (from the date picker).
    func select(date: Date) {
        let newAnchor = min(max(date, HistoryCalendar.earliestDate), Date())
        guard interval != calendar.dateInterval(of: period.calendarComponent, for: newAnchor) else { return }
        anchor = newAnchor
        load()
    }

    /// Returning to the app on a later day: the current period has gained a day.
    func refresh() {
        guard isConfigured else { return }
        load()
    }

    func cancelInFlight() {
        loadTask?.cancel()
        loadTask = nil
    }

    func load() {
        let interval = self.interval
        let period = self.period
        let region = self.region
        let months = Self.months(in: interval)
        let slots = Self.slots(in: interval, period: period)

        isLoading = true
        loadFailed = false
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            do {
                let days = try await HistoryRepository.shared.dailyAverages(region: region, months: months)
                guard !Task.isCancelled, let self else { return }
                self.bars = Self.bars(slots: slots, period: period, days: days)
                self.isLoading = false
            } catch {
                guard !Task.isCancelled, let self else { return }
                let urlError = error as? URLError
                if !(error is CancellationError) && urlError?.code != .cancelled {
                    self.bars = []
                    self.loadFailed = true
                }
                self.isLoading = false
            }
        }
    }

    /// Month starts overlapping `interval`, up to the current month.
    private static func months(in interval: DateInterval) -> [Date] {
        let calendar = HistoryCalendar.calendar
        let lastMonth = HistoryCalendar.monthStart(for: min(interval.end.addingTimeInterval(-1), Date()))
        var month = HistoryCalendar.monthStart(for: interval.start)
        var months: [Date] = []
        while month <= lastMonth {
            months.append(month)
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return months
    }

    /// Start of every bar in the period: days for week/month, months for year.
    private static func slots(in interval: DateInterval, period: HistoryPeriod) -> [Date] {
        let calendar = HistoryCalendar.calendar
        let step: Calendar.Component = period == .year ? .month : .day
        var slots: [Date] = []
        var slot = interval.start
        while slot < interval.end {
            slots.append(slot)
            guard let next = calendar.date(byAdding: step, value: 1, to: slot) else { break }
            slot = next
        }
        return slots
    }

    private static func bars(slots: [Date], period: HistoryPeriod, days: [DailyAveragePrice]) -> [HistoryBar] {
        let today = HistoryCalendar.calendar.startOfDay(for: Date())
        // Tomorrow's day-ahead prices are already in the current month's data,
        // but history ends today.
        let pastDays = days.filter { $0.dayStart <= today.timeIntervalSince1970 }

        if period == .year {
            var byMonth: [String: [Double]] = [:]
            for day in pastDays {
                byMonth[HistoryCalendar.monthKey(for: Date(timeIntervalSince1970: day.dayStart)), default: []].append(day.price)
            }
            return slots.enumerated().map { index, start in
                let prices = byMonth[HistoryCalendar.monthKey(for: start)] ?? []
                let average = prices.isEmpty ? nil : prices.reduce(0, +) / Double(prices.count)
                return HistoryBar(id: index, start: start, rawPriceMWh: average)
            }
        }

        let byDay = Dictionary(pastDays.map { ($0.dayStart, $0.price) }, uniquingKeysWith: { first, _ in first })
        return slots.enumerated().map { index, start in
            HistoryBar(id: index, start: start, rawPriceMWh: byDay[start.timeIntervalSince1970])
        }
    }
}

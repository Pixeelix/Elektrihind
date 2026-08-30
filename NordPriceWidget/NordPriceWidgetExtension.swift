//
//  NordPriceWidgetExtension.swift
//  NordPriceWidgetExtension
//
//  Created by Martin Pihooja on 03.10.2025.
//

import Foundation
import SwiftUI
import WidgetKit
import Charts

private enum WidgetRuntimeConfiguration {
    private static let appGroupID = "group.koodipardik.Elektrihind"
    private static let debugUseTestDataKey = "debugUseTestData"

    static var usesSamplePriceData: Bool {
        #if DEBUG
        if let saved = UserDefaults(suiteName: appGroupID)?.object(forKey: debugUseTestDataKey) as? Bool {
            return saved
        }
        if let saved = UserDefaults.standard.object(forKey: debugUseTestDataKey) as? Bool {
            return saved
        }

        #if targetEnvironment(simulator)
        return true
        #else
        return ProcessInfo.processInfo.arguments.contains("-NordPriceScreenshotMode")
        #endif
        #else
        return false
        #endif
    }
}

// MARK: - Settings bridge for Widget
private enum WidgetSettings {
    
    static let appGroupID = "group.koodipardik.Elektrihind"

    private static var groupDefaults: UserDefaults? {
        let appGroupId = UserDefaults(suiteName: appGroupID)
        return appGroupId
    }

    static func sharedDefaults() -> UserDefaults {
        return UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func cacheKeyForToday(regionCode: String) -> String {
        return CacheKeyGenerator.cacheKeyForToday(regionCode: regionCode)
    }

    static func region() -> String {
        if let region = groupDefaults?.string(forKey: "region"), !region.isEmpty {
            return region
        }
        return Locale.current.region?.identifier ?? "EE"
    }

    static func unit() -> String {
        if let unit = groupDefaults?.string(forKey: "unit"), !unit.isEmpty {
            return unit
        }
        return "€/kWh"
    }

    static func includeTax() -> Bool {
        if let gd = groupDefaults {
            return gd.bool(forKey: "includeTax")
        }
        return UserDefaults.standard.bool(forKey: "includeTax")
    }

    static func taxRate(for region: String) -> Double {
        return TaxConfiguration.taxRate(forCode: region)
    }

    static func numberFormatter(for unit: String) -> (formatter: NumberFormatter, divider: Double) {
        let config = PriceFormatter.formatter(for: unit)
        return (config.formatter, config.divider)
    }
    
    static func chartResolution() -> String {
        if let value = groupDefaults?.string(forKey: "chartResolution"), !value.isEmpty {
            return value
        }
        return ChartResolution.oneHour.rawValue
    }
    
    static func language() -> Language {
        if let code = groupDefaults?.string(forKey: "language"), !code.isEmpty {
            return Language(rawValue: code) ?? .estonian
        }
        return Language.estonian
    }
}

// MARK: - Networking
private enum PriceFetcher {
    /// The widget shares the app's price model so both sides read and write the
    /// exact same cached payload (see SharedPriceCache).
    typealias Point = PriceData

    /// Explicit timeouts: with `URLSession.shared` a hung request means the
    /// extension is killed before `completion` ever fires and WidgetKit gets no
    /// timeline at all. Mirrors PriceAPI in the app target.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 25
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    static func timeZone(for region: String) -> TimeZone {
        return TimeZoneHelper.timeZone(forCode: region)
    }

    /// Complete cached day, or nil.
    static func cachedDay(_ day: Day, region: String) -> [Point]? {
        return SharedPriceCache.load(day: day, region: SharedPriceCache.region(forCode: region))
    }

    /// Anything cached for the day, complete or not. Stale-but-real prices beat
    /// a blank widget when the network is unavailable.
    static func cachedDayBestEffort(_ day: Day, region: String) -> [Point]? {
        return SharedPriceCache.loadBestEffort(day: day, region: SharedPriceCache.region(forCode: region))
    }

    /// Loads today's prices.
    /// - Parameter completion: `nil` means the fetch failed (no network, bad
    ///   response, undecodable body); `[]` means the response was genuinely
    ///   empty. The caller needs to tell those apart to pick a reload policy.
    static func fetchDay(region: String, date: Date = Date(), completion: @escaping ([Point]?) -> Void) {
        if WidgetRuntimeConfiguration.usesSamplePriceData {
            completion(ScreenshotWidgetPriceData.fullDayData(region: region, referenceDate: date))
            return
        }

        // 1) Try the shared cache first — after midnight this is yesterday's
        //    "tomorrow" blob, which lands under today's key.
        if let cached = cachedDay(.today, region: region) {
            completion(cached)
            return
        }

        // 2) Build the same UTC interval as the app's utcInterval(for: .today)
        let interval = UTCInterval.interval(for: .today)
        let urlString = "https://dashboard.elering.ee/api/nps/price?start=\(interval.start)&end=\(interval.end)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        session.dataTask(with: url) { data, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let data = data else {
                completion(nil)
                return
            }
            do {
                let selected = try SharedPriceCache.extractItems(data, for: SharedPriceCache.region(forCode: region))
                // 3) Share the payload with the app and future widget refreshes.
                SharedPriceCache.save(day: .today,
                                      region: SharedPriceCache.region(forCode: region),
                                      payload: data,
                                      items: selected)
                completion(selected)
            } catch {
                completion(nil)
            }
        }.resume()
    }

    /// Now that the widget shares the app's price model, hourly aggregation is
    /// shared too instead of being reimplemented here.
    static func aggregateToHourly(_ points: [Point]) -> [Point] {
        return PriceUtilities.aggregateToHourly(points)
    }
}

private enum ScreenshotWidgetPriceData {
    static func fullDayData(region: String, referenceDate: Date = Date()) -> [PriceFetcher.Point] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZoneHelper.timeZone(forCode: region)

        let dayStart = calendar.startOfDay(for: referenceDate)
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)
        let intervalSeconds: TimeInterval = 15 * 60
        let intervalCount = max(1, Int(nextDayStart.timeIntervalSince(dayStart) / intervalSeconds))
        let quarterAdjustments = [-1.8, 0.7, 2.2, -0.6]
        let regionOffset = offset(for: region)

        return (0..<intervalCount).map { index in
            let hourIndex = min(hourlyPrices.count - 1, index / 4)
            let timestamp = dayStart.addingTimeInterval(TimeInterval(index) * intervalSeconds).timeIntervalSince1970
            let price = hourlyPrices[hourIndex] + quarterAdjustments[index % quarterAdjustments.count] + regionOffset
            return PriceFetcher.Point(timestamp: timestamp, price: price)
        }
    }

    private static let hourlyPrices: [Double] = [
        54, 48, 43, 40, 46, 68, 112, 154,
        139, 104, 82, 71, 64, 58, 55, 63,
        91, 148, 183, 144, 101, 78, 65, 57
    ]

    private static func offset(for region: String) -> Double {
        switch region.uppercased() {
        case "LV": return 3
        case "LT": return 5
        case "FI": return -4
        default: return 0
        }
    }
}

// MARK: - Timeline Entry
struct NordPriceEntry: TimelineEntry {
    let date: Date
    let priceText: String
    let unit: String
    let timeText: String
    let regionCode: String
    fileprivate let prices: [PriceFetcher.Point]
}

// MARK: - Provider
struct NordPriceProvider: TimelineProvider {
    /// WidgetKit archives the whole timeline, and every entry carries its day's
    /// price array for the chart. Capping the entry count keeps that payload
    /// bounded at 15-minute resolution while still comfortably crossing midnight.
    private static let maxEntries = 100

    /// How long to wait before trying again after a failed fetch. Without this
    /// the provider used tomorrow's midnight as the reload date, so a single
    /// failure just after midnight pinned an empty widget for the whole day.
    private static let retryInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> NordPriceEntry {
        NordPriceEntry(date: Date(), priceText: "--", unit: "€/kWh", timeText: "--:--", regionCode: "EE", prices: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (NordPriceEntry) -> Void) {
        buildEntry { entry in
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NordPriceEntry>) -> Void) {
        let region = WidgetSettings.region()
        let unit = WidgetSettings.unit()
        let includeTax = WidgetSettings.includeTax()
        let taxRate = WidgetSettings.taxRate(for: region)
        let (formatter, divider) = WidgetSettings.numberFormatter(for: unit)

        PriceFetcher.fetchDay(region: region) { fetched in
            let fetchFailed = (fetched == nil)
            // On failure fall back to whatever is cached for today rather than
            // rendering an empty chart.
            let todayPoints = fetched ?? PriceFetcher.cachedDayBestEffort(.today, region: region) ?? []
            // Tomorrow is never fetched from the extension — only read from the
            // cache the app populates. When it is there we can keep generating
            // entries past midnight, which is the real safety net: WidgetKit
            // treats the reload policy as a hint, not a guarantee.
            let tomorrowPoints = PriceFetcher.cachedDay(.tomorrow, region: region) ?? []

            let resolution = WidgetSettings.chartResolution()
            let hourly = (resolution == ChartResolution.oneHour.rawValue)
            let interval: TimeInterval = hourly ? 3600 : 900
            let todaySource = hourly ? PriceFetcher.aggregateToHourly(todayPoints) : todayPoints
            let tomorrowSource = hourly ? PriceFetcher.aggregateToHourly(tomorrowPoints) : tomorrowPoints

            let now = Date()
            let start = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970 / interval) * interval)

            let calendar = Calendar.current
            let dayStart = calendar.startOfDay(for: now)
            let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)
            let dayAfterStart = calendar.date(byAdding: .day, value: 1, to: nextDayStart) ?? nextDayStart.addingTimeInterval(24 * 3600)
            let timelineEnd = tomorrowSource.isEmpty ? nextDayStart : dayAfterStart

            let timeString = Self.timeStringBuilder(region: region)
            let priceString = Self.priceStringBuilder(includeTax: includeTax,
                                                      taxRate: taxRate,
                                                      formatter: formatter,
                                                      divider: divider)

            let sortedToday = todaySource.sorted(by: { $0.timestamp < $1.timestamp })
            let sortedTomorrow = tomorrowSource.sorted(by: { $0.timestamp < $1.timestamp })

            var entries: [NordPriceEntry] = []
            var t = start
            while t < timelineEnd && entries.count < Self.maxEntries {
                let afterMidnight = t >= nextDayStart
                let points = afterMidnight ? sortedTomorrow : sortedToday
                let current = points.last { Date(timeIntervalSince1970: $0.timestamp) <= t } ?? points.last
                entries.append(NordPriceEntry(
                    date: t,
                    priceText: priceString(current?.price),
                    unit: unit,
                    timeText: timeString(current?.timestamp),
                    regionCode: region,
                    prices: afterMidnight ? sortedTomorrow : sortedToday
                ))
                t = t.addingTimeInterval(interval)
            }

            if entries.isEmpty {
                // A timeline must contain at least one entry; without data this
                // is a placeholder that the retry policy below will replace.
                entries = [NordPriceEntry(
                    date: start,
                    priceText: priceString(nil),
                    unit: unit,
                    timeText: timeString(nil),
                    regionCode: region,
                    prices: []
                )]
            }

            // A failed fetch means there was no complete cache to serve from
            // either (fetchDay checks the cache first), so retry soon instead of
            // waiting a full day.
            let policy: TimelineReloadPolicy = fetchFailed
                ? .after(now.addingTimeInterval(Self.retryInterval))
                : .after(nextDayStart.addingTimeInterval(5))
            completion(Timeline(entries: entries, policy: policy))
        }
    }

    private func buildEntry(completion: @escaping (NordPriceEntry) -> Void) {
        let region = WidgetSettings.region()
        let unit = WidgetSettings.unit()
        let includeTax = WidgetSettings.includeTax()
        let taxRate = WidgetSettings.taxRate(for: region)
        let (formatter, divider) = WidgetSettings.numberFormatter(for: unit)

        PriceFetcher.fetchDay(region: region) { fetched in
            let dayPoints = fetched ?? PriceFetcher.cachedDayBestEffort(.today, region: region) ?? []
            let resolution = WidgetSettings.chartResolution()
            let hourly = (resolution == ChartResolution.oneHour.rawValue)
            let sourcePoints = hourly ? PriceFetcher.aggregateToHourly(dayPoints) : dayPoints

            let timeString = Self.timeStringBuilder(region: region)
            let priceString = Self.priceStringBuilder(includeTax: includeTax,
                                                      taxRate: taxRate,
                                                      formatter: formatter,
                                                      divider: divider)

            let sorted = sourcePoints.sorted(by: { $0.timestamp < $1.timestamp })
            let now = Date()
            let current: PriceFetcher.Point?
            if hourly {
                let hourStart = Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
                current = sorted.last { Date(timeIntervalSince1970: $0.timestamp) <= hourStart } ?? sorted.last
            } else {
                current = sorted.last { Date(timeIntervalSince1970: $0.timestamp) <= now } ?? sorted.last
            }
            let entry = NordPriceEntry(
                date: now,
                priceText: priceString(current?.price),
                unit: unit,
                timeText: timeString(current?.timestamp),
                regionCode: region,
                prices: sorted
            )
            completion(entry)
        }
    }

    private static func timeStringBuilder(region: String) -> (Double?) -> String {
        let df = DateFormatter()
        df.timeZone = PriceFetcher.timeZone(for: region)
        df.locale = Locale(identifier: WidgetSettings.language().rawValue)
        df.dateFormat = "HH:mm"
        return { ts in
            guard let ts = ts else { return "--:--" }
            return df.string(from: Date(timeIntervalSince1970: ts))
        }
    }

    private static func priceStringBuilder(includeTax: Bool,
                                           taxRate: Double,
                                           formatter: NumberFormatter,
                                           divider: Double) -> (Double?) -> String {
        return { price in
            guard let price = price else { return "---" }
            let adjusted = includeTax ? price * taxRate : price
            return formatter.string(from: NSNumber(value: adjusted / divider)) ?? "---"
        }
    }
}

// MARK: - Widget View
struct NordPriceWidgetEntryView: View {
    var entry: NordPriceProvider.Entry
    @Environment(\.widgetFamily) private var family

    @ViewBuilder
    var body: some View {
        let widgetBundle = Bundle.main
        let lang = WidgetSettings.language()
        let content = VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("TEXT_CURRENT_PRICE".localized(lang, in: widgetBundle))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(entry.timeText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                let isSmall = (family == .systemSmall)
                Text(entry.priceText)
                    .font(.system(size: isSmall ? 40 : 48, weight: .semibold, design: .default))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .minimumScaleFactor(isSmall ? 0.25 : 0.6)
                    .layoutPriority(0)
                Text("\(entry.unit)".localized(lang, in: widgetBundle))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.secondary)
                    .truncationMode(.tail)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }
            if !entry.prices.isEmpty {
                DayPriceChart(points: entry.prices,
                              includeTax: WidgetSettings.includeTax(),
                              taxMultiplier: WidgetSettings.taxRate(for: entry.regionCode),
                              unit: entry.unit,
                              now: entry.date,
                              resolution: WidgetSettings.chartResolution())
                .frame(height: family == .systemSmall ? 60 : 80)
                .padding(.top, 12)
            }
        }

        if #available(iOSApplicationExtension 17.0, *) {
            content
                .containerBackground(for: .widget) { Color(.systemBackground) }
                .widgetURL(URL(string: "nordprice://today"))
        } else {
            content
                .background(Color(.systemBackground))
                .widgetURL(URL(string: "nordprice://today"))
        }
    }
}


// MARK: - Day Price Chart
private struct DayPriceChart: View {
    let points: [PriceFetcher.Point]
    let includeTax: Bool
    let taxMultiplier: Double
    let unit: String
    let now: Date
    let resolution: String

    var body: some View {
        let nfTuple = WidgetSettings.numberFormatter(for: unit)
        let divider = nfTuple.divider

        // Prepare sorted values with adjusted prices scaled by divider
        let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }
        let adjustedPoints: [(date: Date, price: Double)] = sortedPoints.map { p in
            let adjusted = includeTax ? p.price * taxMultiplier : p.price
            let scaled = adjusted / divider
            return (Date(timeIntervalSince1970: p.timestamp), scaled)
        }

        let values: [(date: Date, price: Double)]
        if resolution == "1h" {
            // Downsample to hourly: take the first point for each hour bucket
            let calendar = Calendar.current
            var seenHours = Set<Date>()
            var hourly: [(date: Date, price: Double)] = []
            for item in adjustedPoints {
                let hourStart = calendar.dateInterval(of: .hour, for: item.date)?.start ?? calendar.date(bySetting: .minute, value: 0, of: item.date) ?? item.date
                if !seenHours.contains(hourStart) {
                    seenHours.insert(hourStart)
                    hourly.append((date: hourStart, price: item.price))
                }
            }
            values = hourly
        } else {
            values = adjustedPoints
        }

        let rawMin: Double = values.map { $0.price }.min() ?? 0
        let rawMax: Double = values.map { $0.price }.max() ?? 0
        var yMin = rawMin
        var yMax = rawMax
        if yMin == yMax {
            if yMin == 0 {
                yMin = -1
                yMax = 1
            } else {
                let pad = abs(yMin) * 0.1
                yMin -= pad
                yMax += pad
            }
        } else {
            let span = yMax - yMin
            let pad = max(span * 0.05, 0.01)
            yMin -= pad
            yMax += pad
        }
        yMin = min(yMin, 0)
        yMax = max(yMax, 0)

        let dayStart: Date = {
            if let first = values.first?.date {
                return Calendar.current.startOfDay(for: first)
            } else {
                return Calendar.current.startOfDay(for: Date())
            }
        }()
        let xTicks: [Date] = [0, 6, 12, 18].compactMap { hour in
            Calendar.current.date(byAdding: .hour, value: hour, to: dayStart)
        }
        let dayEnd: Date = Calendar.current.date(byAdding: .hour, value: 24, to: dayStart) ?? dayStart

        // Current point (last point at or before now)
        // let now = Date()
        let currentPoint: (date: Date, price: Double)? = {
            if resolution == "1h" {
                // Align to the start of the current hour
                let calendar = Calendar.current
                let hourStart = calendar.dateInterval(of: .hour, for: now)?.start ?? now
                return values.last { $0.date <= hourStart } ?? values.first
            } else {
                return values.last { $0.date <= now } ?? values.first
            }
        }()

        let yAxisFormatter: NumberFormatter = {
            let f = NumberFormatter()
            f.decimalSeparator = ","
            if unit == "€/kWh" {
                f.minimumFractionDigits = 2
                f.maximumFractionDigits = 2
            } else {
                f.minimumFractionDigits = 0
                f.maximumFractionDigits = 0
            }
            f.maximumIntegerDigits = 6
            return f
        }()

        return Chart {
            ForEach(values, id: \.date) { item in
                LineMark(
                    x: .value("Time", item.date),
                    y: .value("Price", item.price)
                )
                .interpolationMethod(.linear)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(.tint)
            }
            RuleMark(y: .value("Zero", 0))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(.secondary)
            if let current = currentPoint {
                PointMark(
                    x: .value("Time", current.date),
                    y: .value("Price", current.price)
                )
                .symbol(.circle)
                .foregroundStyle(.orange)
            }
        }
        .chartXAxis {
            AxisMarks(values: xTicks) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        let hour = Calendar.current.component(.hour, from: date)
                        Text(String(format: "%02d", hour))
                    }
                }
            }
        }
        .chartXScale(domain: dayStart...dayEnd)
        .chartYScale(domain: yMin...yMax)
        .chartPlotStyle { plotArea in
            plotArea
                .background(.clear)
                .cornerRadius(4)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(yAxisFormatter.string(from: NSNumber(value: d)) ?? String(format: unit == "€/kWh" ? "%.2f" : "%.0f", d))
                    }
                }
            }
        }
    }
}

// MARK: - Widget Definition
// IMPORTANT: Do not mark this struct with @main in the app target.
// Add @main to this struct in your Widget Extension target or wrap it in a WidgetBundle there.
struct NordPriceWidget: Widget {
    let kind: String = "ElektrihindWidgetExtension"
    let widgetBundle = Bundle.main
    let lang = WidgetSettings.language()

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NordPriceProvider()) { entry in
            NordPriceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NordPrice")
        .description("TEXT_WIDGET_DESCRIPTION".localized(lang, in: widgetBundle))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews
struct NordPriceWidget_Previews: PreviewProvider {
    private static var samplePrices: [PriceFetcher.Point] {
        // Generate 24 points with gentle variation
        let start = Date().timeIntervalSince1970 - 23 * 3600
        return (0..<24).map { i in
            let ts = start + Double(i) * 3600
            let base = 80.0 + sin(Double(i) / 3.0) * 15.0
            return PriceFetcher.Point(timestamp: ts, price: base)
        }
    }

    static var previews: some View {
        Group {
            NordPriceWidgetEntryView(
                entry: NordPriceEntry(date: Date(), priceText: "0,1234", unit: "€/kWh", timeText: "12:00", regionCode: "EE", prices: samplePrices)
            )
            .previewContext(WidgetPreviewContext(family: .systemSmall))

            NordPriceWidgetEntryView(
                entry: NordPriceEntry(date: Date(), priceText: "98,7", unit: "€/MWh", timeText: "08:15", regionCode: "FI", prices: samplePrices)
            )
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}

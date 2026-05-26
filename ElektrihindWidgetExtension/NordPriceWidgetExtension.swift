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
        if let region = UserDefaults.standard.string(forKey: "region"), !region.isEmpty {
            return region
        }
            return Locale.current.region?.identifier ?? "EE"
    }

    static func unit() -> String {
        if let unit = groupDefaults?.string(forKey: "unit"), !unit.isEmpty {
            return unit
        }
        if let unit = UserDefaults.standard.string(forKey: "unit"), !unit.isEmpty {
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
        if let value = UserDefaults.standard.string(forKey: "chartResolution"), !value.isEmpty {
            return value
        }
        return "15min"
    }
    
    static func language() -> Language {
        if let code = groupDefaults?.string(forKey: "language"), !code.isEmpty {
            return Language(rawValue: code) ?? .estonian
        }
        if let code = UserDefaults.standard.string(forKey: "language"), !code.isEmpty {
            return Language(rawValue: code) ?? .estonian
        }
        return Language.estonian
    }
}

// MARK: - Networking
private enum PriceFetcher {
    struct Point: Decodable {
        let timestamp: Double
        let price: Double
    }

    struct CountriesResponse: Decodable {
        let data: CountriesData
    }

    struct CountriesData: Decodable {
        let ee: [Point]
        let lv: [Point]
        let lt: [Point]
        let fi: [Point]
    }

    static func timeZone(for region: String) -> TimeZone {
        return TimeZoneHelper.timeZone(forCode: region)
    }

    private struct CachedPayload: Codable {
        let startUTC: String
        let isComplete: Bool
        let payload: Data
        let fetchedAt: Date
    }

    private static func readCachedToday(region: String) -> [Point]? {
        let key = WidgetSettings.cacheKeyForToday(regionCode: region)
        guard let data = WidgetSettings.sharedDefaults().data(forKey: key) else { return nil }
        guard let cached = try? JSONDecoder().decode(CachedPayload.self, from: data) else { return nil }
        guard cached.isComplete else { return nil }
        // Decode payload (same structure as CountriesResponse)
        guard let decoded = try? JSONDecoder().decode(CountriesResponse.self, from: cached.payload) else { return nil }
        switch region.uppercased() {
        case "EE": return decoded.data.ee
        case "LV": return decoded.data.lv
        case "LT": return decoded.data.lt
        case "FI": return decoded.data.fi
        default: return decoded.data.ee
        }
    }

    private static func saveCachedToday(region: String, payload: Data, itemsCount: Int) {
        // Determine expected hours in local day (handles DST 23/24/25)
        let calendar = Calendar.current
        let localStart = calendar.startOfDay(for: Date())
        let nextLocalStart = calendar.date(byAdding: .day, value: 1, to: localStart)!
        let hours = calendar.dateComponents([.hour], from: localStart, to: nextLocalStart).hour ?? 24
        let isComplete = (itemsCount == hours)
        let startUTC = UTCInterval.todayStartUTC()
        let cached = CachedPayload(startUTC: startUTC, isComplete: isComplete, payload: payload, fetchedAt: Date())
        if let blob = try? JSONEncoder().encode(cached) {
            let key = WidgetSettings.cacheKeyForToday(regionCode: region)
            WidgetSettings.sharedDefaults().set(blob, forKey: key)
        }
    }

    static func fetchDay(region: String, date: Date = Date(), completion: @escaping ([Point]) -> Void) {
        if WidgetRuntimeConfiguration.usesSamplePriceData {
            completion(ScreenshotWidgetPriceData.fullDayData(region: region, referenceDate: date))
            return
        }

        // 1) Try shared cache first
        if let cached = readCachedToday(region: region) {
            completion(cached)
            return
        }

        // 2) Build the same UTC interval as the app's utcInterval(for: .today)
        let interval = UTCInterval.interval(for: .today)
        let startString = interval.start
        let endString = interval.end

        let urlString = "https://dashboard.elering.ee/api/nps/price?start=\(startString)&end=\(endString)"
        guard let url = URL(string: urlString) else {
            completion([])
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let data = data else {
                completion([])
                return
            }
            do {
                let decoded = try JSONDecoder().decode(CountriesResponse.self, from: data)
                let selected: [Point]
                switch region.uppercased() {
                case "EE": selected = decoded.data.ee
                case "LV": selected = decoded.data.lv
                case "LT": selected = decoded.data.lt
                case "FI": selected = decoded.data.fi
                default: selected = decoded.data.ee
                }
                // 3) Save payload to shared cache (mark complete if 23/24/25 points)
                saveCachedToday(region: region, payload: data, itemsCount: selected.count)
                completion(selected)
            } catch {
                completion([])
            }
        }.resume()
    }
    
    // Aggregate 15-minute points into hourly averages aligned to the start of the hour
    static func aggregateToHourly(_ points: [Point]) -> [Point] {
        guard !points.isEmpty else { return [] }
        let calendar = Calendar.current
        var buckets: [(start: TimeInterval, values: [Double])] = []
        var currentStart: TimeInterval? = nil
        var currentValues: [Double] = []
        for p in points.sorted(by: { $0.timestamp < $1.timestamp }) {
            let date = Date(timeIntervalSince1970: p.timestamp)
            let comps = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            guard let hourStartDate = calendar.date(from: comps) else { continue }
            let hourStart = hourStartDate.timeIntervalSince1970
            if currentStart == nil { currentStart = hourStart }
            if hourStart != currentStart {
                if let s = currentStart, !currentValues.isEmpty {
                    let avg = currentValues.reduce(0, +) / Double(currentValues.count)
                    buckets.append((start: s, values: [avg]))
                }
                currentStart = hourStart
                currentValues = [p.price]
            } else {
                currentValues.append(p.price)
            }
        }
        if let s = currentStart, !currentValues.isEmpty {
            let avg = currentValues.reduce(0, +) / Double(currentValues.count)
            buckets.append((start: s, values: [avg]))
        }
        return buckets.map { Point(timestamp: $0.start, price: $0.values.first ?? 0) }
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

        PriceFetcher.fetchDay(region: region) { dayPoints in
            let resolution = WidgetSettings.chartResolution()
            let sourcePoints: [PriceFetcher.Point] = (resolution == "1h") ? PriceFetcher.aggregateToHourly(dayPoints) : dayPoints
            let interval: TimeInterval = (resolution == "1h") ? 3600 : 900

            let now = Date()
            let start = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970 / interval) * interval)

            let calendar = Calendar.current
            let dayStart = calendar.startOfDay(for: now)
            let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)

            // Helper closures
            let timeString: (Double?) -> String = { ts in
                guard let ts = ts else { return "--:--" }
                let df = DateFormatter()
                df.timeZone = PriceFetcher.timeZone(for: region)
                df.locale = Locale(identifier: WidgetSettings.language().rawValue)
                df.dateFormat = "HH:mm"
                return df.string(from: Date(timeIntervalSince1970: ts))
            }
            let priceString: (Double?) -> String = { price in
                guard let price = price else { return "---" }
                let adjusted = includeTax ? price * taxRate : price
                return formatter.string(from: NSNumber(value: adjusted / divider)) ?? "---"
            }

            let sorted = sourcePoints.sorted(by: { $0.timestamp < $1.timestamp })

            var entries: [NordPriceEntry] = []
            var t = start
            while t < nextDayStart {
                let current = sorted.last { Date(timeIntervalSince1970: $0.timestamp) <= t } ?? sorted.last
                let entry = NordPriceEntry(
                    date: t,
                    priceText: priceString(current?.price),
                    unit: unit,
                    timeText: timeString(current?.timestamp),
                    regionCode: region,
                    prices: sourcePoints
                )
                entries.append(entry)
                t = t.addingTimeInterval(interval)
            }

            let policy: TimelineReloadPolicy = .after(nextDayStart.addingTimeInterval(5))
            completion(Timeline(entries: entries, policy: policy))
        }
    }

    private func buildEntry(completion: @escaping (NordPriceEntry) -> Void) {
        let region = WidgetSettings.region()
        let unit = WidgetSettings.unit()
        let includeTax = WidgetSettings.includeTax()
        let taxRate = WidgetSettings.taxRate(for: region)
        let (formatter, divider) = WidgetSettings.numberFormatter(for: unit)

        PriceFetcher.fetchDay(region: region) { dayPoints in
            let resolution = WidgetSettings.chartResolution()
            let sourcePoints: [PriceFetcher.Point] = (resolution == "1h") ? PriceFetcher.aggregateToHourly(dayPoints) : dayPoints

            // Helper closures
            let timeString: (Double?) -> String = { ts in
                guard let ts = ts else { return "--:--" }
                let df = DateFormatter()
                df.timeZone = PriceFetcher.timeZone(for: region)
                df.locale = Locale(identifier: WidgetSettings.language().rawValue)
                df.dateFormat = "HH:mm"
                return df.string(from: Date(timeIntervalSince1970: ts))
            }
            let priceString: (Double?) -> String = { price in
                guard let price = price else { return "---" }
                let adjusted = includeTax ? price * taxRate : price
                return formatter.string(from: NSNumber(value: adjusted / divider)) ?? "---"
            }

            let sorted = sourcePoints.sorted(by: { $0.timestamp < $1.timestamp })
            let now = Date()
            let current: PriceFetcher.Point?
            if resolution == "1h" {
                let hourStart = Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
                current = sorted.last { Date(timeIntervalSince1970: $0.timestamp) <= hourStart } ?? sorted.last
            } else {
                current = sorted.last { Date(timeIntervalSince1970: $0.timestamp) <= now } ?? sorted.last
            }
            let entry = NordPriceEntry(
                date: Date(),
                priceText: priceString(current?.price),
                unit: unit,
                timeText: timeString(current?.timestamp),
                regionCode: region,
                prices: sourcePoints
            )
            completion(entry)
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

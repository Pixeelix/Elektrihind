//
//  HistoryView.swift
//  NordPrice
//
//  Price history tab: pick week / month / year, step through past periods and
//  see the period average, its cheapest and most expensive day (or month) and a
//  chart of daily (or monthly) averages.
//

import SwiftUI
import Charts

struct HistoryView: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject var settings: AppSettings
    @StateObject private var viewModel = HistoryViewModel()
    @ScaledMetric(relativeTo: .body) private var sideColumnWidth: CGFloat = 340

    /// Full-screen iPad: cards beside the chart, like the dashboard.
    private var isWide: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    var body: some View {
        Group {
            if isWide {
                wideLayout
            } else {
                phoneLayout
            }
        }
        .scrollsAtAccessibilitySizes()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            viewModel.configure(region: settings.region)
        }
        .onChange(of: settings.region) { region in
            viewModel.configure(region: region)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                viewModel.refresh()
            } else if newPhase == .background {
                viewModel.cancelInFlight()
            }
        }
    }

    private var phoneLayout: some View {
        VStack(alignment: .center) {
            TitleView(title: settings.localizedString("TITLE_PRICE_HISTORY"))
            HistoryAverageView(viewModel: viewModel)
            HistoryMinMaxView(viewModel: viewModel)
            HistoryPeriodPicker(viewModel: viewModel)
                .cardWidth()
                .padding(.vertical, 2)
            HistoryChartView(viewModel: viewModel)
                .padding(.bottom, 8)
            if !AppRuntimeConfiguration.hidesAdBanners {
                AdaptiveBannerAd(unitID: AdUnit.historyBanner, tabs: [3])
                    .padding(.bottom, 4)
            }
        }
    }

    private var wideLayout: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    TitleView(title: settings.localizedString("TITLE_PRICE_HISTORY"))
                    HistoryAverageView(viewModel: viewModel)
                    HistoryMinMaxView(viewModel: viewModel)
                    HistoryPeriodPicker(viewModel: viewModel)
                }
                .frame(maxWidth: sideColumnWidth, alignment: .top)

                HistoryChartView(viewModel: viewModel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if !AppRuntimeConfiguration.hidesAdBanners {
                AdaptiveBannerAd(unitID: AdUnit.historyBanner, tabs: [3])
            }
        }
        .environment(\.cardWidth, nil)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

// MARK: - Formatting

/// Price and date formatting shared by the history cards and chart.
private struct HistoryFormat {
    let settings: AppSettings
    let period: HistoryPeriod

    var locale: Locale {
        switch settings.language {
        case .english: return Locale(identifier: "en_US")
        case .finnish: return Locale(identifier: "fi_FI")
        case .estonian: return Locale(identifier: "et_EE")
        case .russian: return Locale(identifier: "ru_RU")
        }
    }

    /// Raw €/MWh in the user's unit, with VAT if enabled.
    func displayPrice(_ rawMWh: Double) -> Double {
        let price = rawMWh / settings.divider
        return settings.includeTax ? price * settings.taxRate : price
    }

    func priceText(_ rawMWh: Double?) -> String {
        guard let rawMWh else { return "---" }
        return settings.numberFormatter.string(from: NSNumber(value: displayPrice(rawMWh))) ?? "---"
    }

    func dateFormatter(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = HistoryCalendar.calendar
        formatter.timeZone = HistoryCalendar.calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    /// Date of one bar: "Mon, 5 Oct" for days, "October 2026" for months.
    func barDate(_ date: Date) -> String {
        dateFormatter(period == .year ? "LLLLyyyy" : "EEEdMMM").string(from: date)
    }

    /// Short date of one bar for the min/max card: "5 Oct" or "Oct".
    func shortBarDate(_ date: Date) -> String {
        dateFormatter(period == .year ? "LLL" : "dMMM").string(from: date)
    }

    func periodTitle(_ interval: DateInterval) -> String {
        switch period {
        case .week:
            let formatter = DateIntervalFormatter()
            formatter.calendar = HistoryCalendar.calendar
            formatter.timeZone = HistoryCalendar.calendar.timeZone
            formatter.locale = locale
            formatter.dateTemplate = "dMMM"
            return formatter.string(from: interval.start, to: interval.end.addingTimeInterval(-1))
        case .month:
            return dateFormatter("LLLLyyyy").string(from: interval.start).capitalized(with: locale)
        case .year:
            return dateFormatter("yyyy").string(from: interval.start)
        }
    }
}

// MARK: - Period picker

private struct HistoryPeriodPicker: View {
    @EnvironmentObject var settings: AppSettings
    @ObservedObject var viewModel: HistoryViewModel

    var body: some View {
        Picker(settings.localizedString("TITLE_PERIOD"), selection: $viewModel.period) {
            ForEach(HistoryPeriod.allCases, id: \.self) { period in
                Text(settings.localizedString(period.localizationKey)).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - Average card

/// Same shape as the current-price card: the period's average price in large
/// type, with arrows to step to the previous / next period. Tapping the period
/// title opens a date picker.
private struct HistoryAverageView: View {
    @EnvironmentObject var settings: AppSettings
    @ObservedObject var viewModel: HistoryViewModel
    @State private var showDatePicker = false
    @ScaledMetric(relativeTo: .largeTitle) private var priceHeight: CGFloat = UIScreen.isTallScreen ? 62 : 52
    @ScaledMetric(relativeTo: .title2) private var unitFontSize: CGFloat = 20

    private var format: HistoryFormat { HistoryFormat(settings: settings, period: viewModel.period) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                arrowButton("chevron.left", label: "A11Y_PREVIOUS_PERIOD",
                            enabled: viewModel.canGoBack, action: viewModel.goBack)
                Spacer()
                Button {
                    showDatePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text(format.periodTitle(viewModel.interval))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .accessibilityHidden(true)
                    }
                    .font(.headline)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .foregroundStyle(Color.bluewWhiteText)
                .accessibilityHint(settings.localizedString("TITLE_SELECT_DATE"))
                Spacer()
                arrowButton("chevron.right", label: "A11Y_NEXT_PERIOD",
                            enabled: viewModel.canGoForward, action: viewModel.goForward)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)

            VStack {
                Text(averageText)
                    .font(.system(size: 300, weight: .medium))
                    .minimumScaleFactor(0.01)
                    .redacted(reason: viewModel.isLoading ? .placeholder : [])
            }
            .frame(height: priceHeight)
            .padding(.top, -8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(settings.localizedString("TITLE_PERIOD_AVERAGE"))
            .accessibilityValue("\(averageText) \(settings.localizedString(settings.unit))")

            Text("\(settings.localizedString(settings.unit)) · \(settings.localizedString("TITLE_PERIOD_AVERAGE"))")
                .font(.system(size: unitFontSize, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .accessibilityHidden(true)
        }
        .cardWidth()
        .frame(minHeight: UIScreen.isTallScreen ? 120 : 100, alignment: .top)
        .heroCardStyle(cornerRadius: 16)
        .sheet(isPresented: $showDatePicker) {
            HistoryDatePickerSheet(viewModel: viewModel)
                .environmentObject(settings)
        }
    }

    private var averageText: String {
        viewModel.isLoading ? "0,00" : format.priceText(viewModel.averageRawMWh)
    }

    private func arrowButton(_ systemName: String, label: String, enabled: Bool,
                             action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.playSelection()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.headline)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .foregroundStyle(Color.brand)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(settings.localizedString(label))
    }
}

// MARK: - Date picker

/// Week and month: a calendar, any day picks the week / month containing it.
/// Year: a wheel of years.
private struct HistoryDatePickerSheet: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HistoryViewModel
    @State private var date: Date
    @State private var year: Int

    private var format: HistoryFormat { HistoryFormat(settings: settings, period: viewModel.period) }
    private var calendar: Calendar { HistoryCalendar.calendar }
    private var years: [Int] {
        Array(calendar.component(.year, from: HistoryCalendar.earliestDate)...calendar.component(.year, from: Date()))
    }

    init(viewModel: HistoryViewModel) {
        self.viewModel = viewModel
        _date = State(initialValue: viewModel.anchor)
        _year = State(initialValue: HistoryCalendar.calendar.component(.year, from: viewModel.anchor))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.period == .year {
                    Picker(settings.localizedString("PERIOD_YEAR"), selection: $year) {
                        ForEach(years, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                } else {
                    DatePicker(settings.localizedString("TITLE_SELECT_DATE"),
                               selection: $date,
                               in: HistoryCalendar.earliestDate...Date(),
                               displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .onChange(of: date) { newDate in
                            // A tap on a day is the whole choice; no need for "Done".
                            viewModel.select(date: newDate)
                            dismiss()
                        }
                }
            }
            .padding(.horizontal)
            .frame(maxHeight: .infinity, alignment: .top)
            .tint(.brand)
            .environment(\.locale, format.locale)
            .environment(\.calendar, calendar)
            .environment(\.timeZone, calendar.timeZone)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // The app's navigation bar appearance draws titles in white, which
                // disappears on the light sheet; a principal item keeps it readable.
                ToolbarItem(placement: .principal) {
                    Text(settings.localizedString("TITLE_SELECT_DATE"))
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.localizedString("BUTTON_CANCEL")) { dismiss() }
                }
                if viewModel.period == .year {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(settings.localizedString("BUTTON_DONE")) {
                            if let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) {
                                viewModel.select(date: start)
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents(viewModel.period == .year ? [.height(320)] : [.medium, .large])
    }
}

// MARK: - Min / max card

/// Like `MinAvgMaxView`, with the date of the cheapest and most expensive bar
/// under each value (the average already has the big card).
private struct HistoryMinMaxView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var viewModel: HistoryViewModel
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 18
    @ScaledMetric(relativeTo: .footnote) private var dateFontSize: CGFloat = 13

    private var format: HistoryFormat { HistoryFormat(settings: settings, period: viewModel.period) }

    private var items: [(key: String, bar: HistoryBar?)] {
        [("TITLE_MIN", viewModel.isLoading ? nil : viewModel.cheapestBar),
         ("TITLE_MAX", viewModel.isLoading ? nil : viewModel.mostExpensiveBar)]
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.key) { item in
                        HStack {
                            label(item.key)
                            Spacer()
                            VStack(alignment: .trailing) {
                                value(item.bar)
                                date(item.bar)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } else {
                HStack(alignment: .top) {
                    ForEach(items, id: \.key) { item in
                        VStack(alignment: .center, spacing: 2) {
                            label(item.key)
                            value(item.bar)
                            date(item.bar)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .cardWidth()
        .frame(minHeight: UIScreen.is1stGenIphone ? 50 : 60)
        .foregroundColor(Color.bluewWhiteText)
        .cardStyle(cornerRadius: 14)
    }

    private func label(_ key: String) -> some View {
        Text(settings.localizedString(key))
            .font(.system(size: fontSize, weight: .medium))
            .foregroundColor(Color.cardLabelText)
    }

    private func value(_ bar: HistoryBar?) -> some View {
        HStack(spacing: 6) {
            if settings.colorfulChart, let level = bar?.level {
                Circle()
                    .fill(level.color)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
            Text(format.priceText(bar?.rawPriceMWh))
                .font(.system(size: fontSize, weight: .bold))
        }
    }

    private func date(_ bar: HistoryBar?) -> some View {
        Text(bar.map { format.shortBarDate($0.start) } ?? " ")
            .font(.system(size: dateFontSize, weight: .medium))
            .foregroundStyle(Color.secondary)
    }
}

// MARK: - Chart

private struct HistoryChartView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var viewModel: HistoryViewModel

    @State private var selectedIndex: Int? = nil

    @ScaledMetric(relativeTo: .caption2) private var xAxisFontSize: CGFloat = 11
    @ScaledMetric(relativeTo: .caption2) private var yAxisFontSize: CGFloat = 9
    @ScaledMetric(relativeTo: .caption2) private var legendFontSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption2) private var legendDotSize: CGFloat = 7
    private var axisFontCap: CGFloat { 15 }

    private var barColor: Color { Color.bluewWhiteText }
    private let lineColor: Color = .brand

    private var format: HistoryFormat { HistoryFormat(settings: settings, period: viewModel.period) }

    private var minChartHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 380 : min(ChartForm.barChartHeight, 220)
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .brand))
                    .foregroundColor(.bluewWhiteText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.loadFailed {
                message(settings.localizedString("TEXT_HISTORY_LOAD_FAILED"), retry: true)
            } else if !viewModel.hasData {
                message(settings.localizedString("TEXT_NO_HISTORY_DATA"), retry: false)
            } else {
                chartContent
            }
        }
        .cardWidth()
        .frame(minHeight: minChartHeight, maxHeight: .infinity)
        .cardStyle(cornerRadius: 14)
        .onChange(of: viewModel.anchor) { _ in selectedIndex = nil }
        .onChange(of: viewModel.period) { _ in selectedIndex = nil }
    }

    private func message(_ text: String, retry: Bool) -> some View {
        VStack(spacing: 12) {
            Text(text)
                .font(.headline)
                .foregroundColor(Color.bluewWhiteText)
                .multilineTextAlignment(.center)
            if retry {
                Button(settings.localizedString("BUTTON_RETRY")) {
                    viewModel.load()
                }
                .buttonStyle(.bordered)
                .tint(.brand)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func levelColor(for bar: HistoryBar) -> Color {
        guard settings.colorfulChart else { return barColor }
        return bar.level?.color ?? lineColor
    }

    private var headerTitle: String {
        settings.localizedString(viewModel.period == .year ? "TITLE_MONTHLY_AVERAGE" : "TITLE_DAILY_AVERAGE")
    }

    private var chartContent: some View {
        let bars = viewModel.bars
        let priced = bars.filter { $0.rawPriceMWh != nil }
        let prices = priced.compactMap { $0.rawPriceMWh.map(format.displayPrice) }
        let yMin = min(prices.min() ?? 0, 0)
        var yMax = max(prices.max() ?? 1, 0.01)
        yMax += (yMax - yMin) * 0.1
        let average = viewModel.averageRawMWh.map(format.displayPrice)
        let count = bars.count
        let selected = selectedIndex.flatMap { index in priced.first { $0.id == index } }

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let selected, let raw = selected.rawPriceMWh {
                    Text("\(format.priceText(raw)) \(settings.localizedString(settings.unit))")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(format.barDate(selected.start))
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Text(headerTitle)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                }
                Button {
                    settings.chartType = (settings.chartType == .bar) ? .line : .bar
                } label: {
                    Image(systemName: settings.chartType.systemImage)
                        .font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .padding(.vertical, -10)
                .accessibilityLabel(settings.localizedString(
                    settings.chartType == .bar ? "A11Y_SHOW_LINE_CHART" : "A11Y_SHOW_BAR_CHART"))
            }
            .foregroundStyle(barColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Chart {
                // Period average as a dashed guide, so above/below-average days
                // stand out.
                if let average {
                    RuleMark(y: .value("Average", average))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Color.primary.opacity(0.4))
                        .accessibilityHidden(true)
                }

                ForEach(priced) { bar in
                    marks(for: bar, count: count)
                }

                if yMin < 0 {
                    RuleMark(y: .value("Zero", 0))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .accessibilityHidden(true)
                }

                if let selected {
                    RuleMark(x: .value("Selected", Double(selected.id)))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .accessibilityHidden(true)
                }
            }
            .chartXScale(domain: -0.6...(Double(max(count, 1)) - 0.4))
            .chartYScale(domain: yMin...yMax)
            .chartXAxis {
                AxisMarks(values: xTicks(count: count).map(Double.init)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisTick()
                    AxisValueLabel(centered: false) {
                        if let position = value.as(Double.self), Int(position) < bars.count {
                            Text(xLabel(for: bars[Int(position)].start))
                                .font(.system(size: min(xAxisFontSize, axisFontCap), weight: .semibold))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.2))
                    AxisTick()
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(yLabel(d))
                                .font(.system(size: min(yAxisFontSize, axisFontCap)))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let x = value.location.x - geometry[plotFrame].origin.x
                                    guard let position: Double = proxy.value(atX: x) else { return }
                                    let index = max(0, min(count - 1, Int(position.rounded())))
                                    guard bars[index].rawPriceMWh != nil, index != selectedIndex else { return }
                                    selectedIndex = index
                                    HapticFeedback.playSelection()
                                }
                                .onEnded { _ in
                                    // Not animated, see ChartView: it would cross-fade
                                    // the whole chart.
                                    selectedIndex = nil
                                }
                        )
                }
            }
            .accessibilityLabel(settings.localizedString("A11Y_PRICE_CHART"))
            .padding(.leading, 10)
            .padding(.trailing, 20)
            .padding(.bottom, 4)

            if settings.colorfulChart {
                levelLegend
                    .padding(.horizontal)
                    .padding(.bottom, 10)
            } else {
                Spacer().frame(height: 6)
            }
        }
    }

    private func barFill(for bar: HistoryBar) -> Color {
        let dimmed = selectedIndex != nil && selectedIndex != bar.id
        return levelColor(for: bar).opacity(dimmed ? 0.45 : 1)
    }

    @ChartContentBuilder
    private func marks(for bar: HistoryBar, count: Int) -> some ChartContent {
        let price: Double = format.displayPrice(bar.rawPriceMWh ?? 0)
        let x = Double(bar.id)
        if settings.chartType == .bar {
            // A rectangle with explicit edges: BarMark's `width: .ratio` has no
            // band to be a ratio of on a numeric axis, and the bars vanish.
            RectangleMark(
                xStart: .value("Start", x - 0.35),
                xEnd: .value("End", x + 0.35),
                yStart: .value("Base", 0.0),
                yEnd: .value("Price", price)
            )
            .foregroundStyle(barFill(for: bar))
            .cornerRadius(count > 20 ? 1.5 : 3)
            .accessibilityLabel(format.barDate(bar.start))
            .accessibilityValue(accessibilityValue(for: bar))
        } else {
            LineMark(
                x: .value("Time", x),
                y: .value("Price", price)
            )
            .foregroundStyle(lineColor)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)
            .accessibilityLabel(format.barDate(bar.start))
            .accessibilityValue(accessibilityValue(for: bar))

            AreaMark(
                x: .value("Time", x),
                y: .value("Price", price)
            )
            .foregroundStyle(LinearGradient(colors: [lineColor.opacity(0.3), lineColor.opacity(0.03)],
                                            startPoint: .top, endPoint: .bottom))
            .interpolationMethod(.monotone)
            .accessibilityHidden(true)

            PointMark(
                x: .value("Time", x),
                y: .value("Price", price)
            )
            .symbol {
                Circle()
                    .fill(levelColor(for: bar))
                    .frame(width: count > 20 ? 6 : 9, height: count > 20 ? 6 : 9)
            }
            .accessibilityHidden(true)
        }
    }

    /// Week: every day. Month: the 1st, 8th, 15th, 22nd and 29th. Year: every
    /// other month (every month on the wide iPad chart would also fit, but the
    /// phone is the narrow case).
    private func xTicks(count: Int) -> [Int] {
        switch viewModel.period {
        case .week: return Array(0..<count)
        case .month: return stride(from: 0, to: count, by: 7).map { $0 }
        case .year: return stride(from: 0, to: count, by: 2).map { $0 }
        }
    }

    private func xLabel(for date: Date) -> String {
        switch viewModel.period {
        case .week: return format.dateFormatter("EEE").string(from: date)
        case .month: return format.dateFormatter("d").string(from: date)
        case .year: return format.dateFormatter("LLL").string(from: date)
        }
    }

    private func yLabel(_ value: Double) -> String {
        settings.unit == "€/kWh" ? String(format: "%.2f", value) : String(format: "%.0f", value)
    }

    private func accessibilityValue(for bar: HistoryBar) -> String {
        let price = "\(format.priceText(bar.rawPriceMWh)) \(settings.localizedString(settings.unit))"
        guard let level = bar.level else { return price }
        return "\(price), \(settings.localizedString(level.localizationKey))"
    }

    @ViewBuilder
    private var levelLegend: some View {
        if dynamicTypeSize.isAccessibilitySize {
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                                GridItem(.flexible(), alignment: .leading)],
                      alignment: .leading, spacing: 6) {
                legendItems
            }
        } else {
            HStack(spacing: 12) {
                legendItems
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var legendItems: some View {
        ForEach(PriceLevel.allCases, id: \.self) { level in
            HStack(spacing: 4) {
                Circle()
                    .fill(level.color)
                    .frame(width: legendDotSize, height: legendDotSize)
                    .accessibilityHidden(true)
                Text(settings.localizedString(level.localizationKey))
                    .font(.system(size: legendFontSize, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
            .environmentObject(AppSettings())
            .background(Color.backgroundColor.edgesIgnoringSafeArea(.all))
    }
}

//
//  ChartView.swift
//  NordPrice
//
//  Created by Martin Pihooja on 05.04.2023.
//

import SwiftUI
import Charts

struct ChartView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var day: Day
    @ObservedObject var viewModel: ChartViewModel

    @State private var selectedIndex: Int? = nil
    @State private var showSelection: Bool = false

    // Chart text grows with Dynamic Type; default values match the design.
    @ScaledMetric(relativeTo: .caption2) private var badgeFontSize: CGFloat = 9
    @ScaledMetric(relativeTo: .caption2) private var xAxisFontSize: CGFloat = 11
    @ScaledMetric(relativeTo: .caption2) private var yAxisFontSize: CGFloat = 9
    @ScaledMetric(relativeTo: .caption2) private var legendFontSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption2) private var legendDotSize: CGFloat = 7
    /// Axis labels and the badge sit inside the plot, so they stop growing
    /// before they crowd out the bars.
    private var axisFontCap: CGFloat { 15 }

    private var barColor: Color { Color.bluewWhiteText }
    /// Current-interval highlight of the single-color chart (price colors off).
    private let currentColor = Color(hexString: "#FF964F")
    /// Line chart color, brand blue like the website's chart.
    private let lineColor: Color = .brand
    /// Upcoming bars keep their level color, slightly softened so the current
    /// bar (full strength, wider, labelled) stands out.
    private let futureBarOpacity: Double = 0.8
    /// Elapsed bars are neutral gray: the level no longer matters once the
    /// interval is over, and gray separates past from future at a glance.
    private var pastBarColor: Color { Color.gray.opacity(colorScheme == .dark ? 0.35 : 0.3) }

    private func levelColor(for entry: PriceChartEntry) -> Color {
        entry.level?.color ?? lineColor
    }

    private func barStyle(for entry: PriceChartEntry, currentIndex: Int?) -> Color {
        let color = levelColor(for: entry)
        // Tomorrow (or any day without a current interval): all bars upcoming.
        guard let currentIndex else { return color }
        if entry.id == currentIndex { return color }
        return entry.id < currentIndex ? pastBarColor : color.opacity(futureBarOpacity)
    }

    /// Small capsule above the current bar, in the bar's own level color.
    private func nowBadge(for entry: PriceChartEntry) -> some View {
        Text(settings.localizedString("LABEL_NOW"))
            .font(.system(size: min(badgeFontSize, 13), weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(levelColor(for: entry)))
            .accessibilityHidden(true)
    }

    /// Line chart: opacity of the current/future part vs. the part of the day
    /// that has already passed (mirrors the website's past/future split).
    private let lineFutureOpacity: Double = 1.0
    private let linePastOpacity: Double = 0.4
    private var areaFutureOpacity: Double { colorScheme == .dark ? 0.3 : 0.25 }
    private var areaPastOpacity: Double { colorScheme == .dark ? 0.12 : 0.1 }

    /// Horizontal gradient with one stop per data point, colored by that
    /// interval's price level. Swift Charts maps a gradient on a line/area series
    /// to the series' own bounds, so point `i` sits at `i / (n - 1)`. Between two
    /// points the color blends linearly, i.e. a level change fades over exactly
    /// one interval: smooth, but never out of step with the legend.
    private func levelGradient(_ entries: [PriceChartEntry], future: Double, past: Double) -> LinearGradient {
        let n = entries.count
        guard n > 1 else {
            let color = entries.first.map { levelColor(for: $0) } ?? lineColor
            return LinearGradient(colors: [color.opacity(future), color.opacity(future)],
                                  startPoint: .leading, endPoint: .trailing)
        }
        let currentIndex = entries.firstIndex(where: \.isCurrent)
        let stops = entries.enumerated().map { index, entry in
            let isPast = currentIndex.map { index < $0 } ?? false
            return Gradient.Stop(color: levelColor(for: entry).opacity(isPast ? past : future),
                                 location: Double(index) / Double(n - 1))
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    init(day: Day, viewModel: ChartViewModel) {
        self.day = day
        self.viewModel = viewModel
    }

    private var chartSize: CGSize {
        CGSize(width: UIScreen.main.bounds.width * 0.9, height: ChartForm.barChartHeight)
    }

    /// The chart grows to fill whatever the screen leaves after the cards and
    /// the ad banner; this is only the floor for very small screens.
    private var minChartHeight: CGFloat {
        // At accessibility sizes the screen scrolls, so the chart gets a fixed,
        // readable height instead of filling the leftover space.
        dynamicTypeSize.isAccessibilitySize ? 380 : min(chartSize.height, 220)
    }

    var body: some View {
        VStack {
            if viewModel.isLoading {
                VStack {
                    ProgressView("Loading...")
                }
                .progressViewStyle(CircularProgressViewStyle(tint: .brand))
                .foregroundColor(.bluewWhiteText)
                .frame(width: chartSize.width)
                .frame(minHeight: minChartHeight, maxHeight: .infinity)
                .cardStyle(cornerRadius: 14)
            } else {
                chartContent
            }
        }
    }

    private var chartContent: some View {
        let entries = viewModel.chartEntries
        let prices = entries.map { $0.price }
        let rawMin = prices.min() ?? 0
        let rawMax = prices.max() ?? 1
        var yMin = min(rawMin, 0)
        var yMax = max(rawMax, 0.01)
        let span = yMax - yMin
        let topPad = span * 0.1
        yMax += topPad
        let hasNegative = rawMin < 0
        let currentIndex = entries.firstIndex(where: \.isCurrent)
        let isFifteenMin = settings.chartResolution == .fifteenMinutes
        // Off: the original single-color chart, without level colors or legend.
        let colorful = settings.colorfulChart

        // X-axis tick indices for 00, 06, 12, 18
        let count = entries.count
        let xTicks: [Int] = {
            if count <= 1 { return [0] }
            let pointsPerHour = Double(count) / 24.0
            return [0, 6, 12, 18].map { Int(Double($0) * pointsPerHour) }
        }()

        // Y-axis formatter
        let yFormatter: (Double) -> String = { value in
            let unit = settings.unit
            if unit == "€/kWh" || unit == "snt/kWh" || unit == "c/kWh" {
                return String(format: "%.2f", value)
            } else {
                return String(format: "%.0f", value)
            }
        }

        let lineGradient = levelGradient(entries, future: lineFutureOpacity, past: linePastOpacity)
        let areaGradient = levelGradient(entries, future: areaFutureOpacity, past: areaPastOpacity)

        return ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header: selected value or chart type toggle
                HStack {
                    if showSelection, let idx = selectedIndex, idx >= 0, idx < entries.count {
                        let header = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading))
                            : AnyLayout(HStackLayout())
                        header {
                            Text("\(entries[idx].price, specifier: viewModel.specifier)")
                                .font(.headline)
                                .foregroundStyle(barColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(entries[idx].timeLabel)
                                .font(.headline)
                                .foregroundStyle(barColor)
                                .frame(maxWidth: .infinity,
                                       alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
                        }
                    } else {
                        Text(titleText)
                            .font(.headline)
                            .foregroundStyle(barColor)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                    }
                    Button {
                        settings.chartType = (settings.chartType == .bar) ? .line : .bar
                    } label: {
                        Image(systemName: settings.chartType.systemImage)
                            .font(.title3)
                            .foregroundStyle(barColor)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .padding(.vertical, -10)
                    .accessibilityLabel(settings.localizedString(
                        settings.chartType == .bar ? "A11Y_SHOW_LINE_CHART" : "A11Y_SHOW_BAR_CHART"))
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Chart
                Chart {
                    // "Now" guide behind the bars, so the current slot is easy to
                    // find even when its bar is short.
                    if colorful, settings.chartType == .bar, let currentIndex {
                        RuleMark(x: .value("Now", currentIndex))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .foregroundStyle(Color.primary.opacity(0.35))
                            .accessibilityHidden(true)
                    }

                    ForEach(entries) { entry in
                        if !colorful {
                            plainMarks(for: entry, isFifteenMin: isFifteenMin)
                        } else if settings.chartType == .bar {
                            BarMark(
                                x: .value("Time", entry.id),
                                y: .value("Price", entry.price),
                                width: isFifteenMin ? .fixed(entry.isCurrent ? 4 : 2) : .automatic
                            )
                            .foregroundStyle(barStyle(for: entry, currentIndex: currentIndex))
                            .accessibilityLabel(accessibilityLabel(for: entry))
                            .accessibilityValue(accessibilityValue(for: entry))
                        } else {
                            LineMark(
                                x: .value("Time", entry.id),
                                y: .value("Price", entry.price)
                            )
                            .foregroundStyle(lineGradient)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                            .accessibilityLabel(accessibilityLabel(for: entry))
                            .accessibilityValue(accessibilityValue(for: entry))

                            AreaMark(
                                x: .value("Time", entry.id),
                                y: .value("Price", entry.price)
                            )
                            .foregroundStyle(areaGradient)
                            .interpolationMethod(.catmullRom)
                            .accessibilityHidden(true)

                            if entry.isCurrent {
                                PointMark(
                                    x: .value("Time", entry.id),
                                    y: .value("Price", entry.price)
                                )
                                .symbol {
                                    Circle()
                                        .fill(levelColor(for: entry))
                                        .frame(width: 11, height: 11)
                                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                                        .shadow(color: .black.opacity(0.25), radius: 2)
                                }
                                .accessibilityHidden(true)
                            }
                        }
                    }

                    // "Now" badge: an invisible point on top of the current bar,
                    // declared after all bars so neighbouring bars can't cover it.
                    if colorful, settings.chartType == .bar, let currentIndex {
                        let current = entries[currentIndex]
                        PointMark(
                            x: .value("Time", current.id),
                            y: .value("Price", max(current.price, 0))
                        )
                        .opacity(0)
                        .accessibilityHidden(true)
                        .annotation(position: .top, spacing: 3,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                            nowBadge(for: current)
                        }
                    }

                    // Zero line — more prominent when negative prices exist
                    if hasNegative {
                        RuleMark(y: .value("Zero", 0))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            .foregroundStyle(Color.primary.opacity(0.5))
                            .accessibilityHidden(true)
                    }

                    // Selected index indicator
                    if showSelection, let idx = selectedIndex, idx >= 0, idx < entries.count {
                        RuleMark(x: .value("Selected", idx))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            .foregroundStyle(colorful ? Color.primary.opacity(0.5) : currentColor.opacity(0.6))
                            .accessibilityHidden(true)
                    }
                }
                .chartXScale(domain: -1...(max(count - 1, 1)))
                .chartYScale(domain: yMin...yMax)
                .chartXAxis {
                    AxisMarks(values: xTicks) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.gray.opacity(0.3))
                        AxisTick()
                        AxisValueLabel {
                            if let idx = value.as(Int.self) {
                                let hour = Int(round(Double(idx) * 24.0 / Double(max(count, 1))))
                                Text(String(format: "%02d", hour))
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
                                Text(yFormatter(d))
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
                                        // The gesture reports overlay coordinates, but the
                                        // proxy expects plot-area ones: the leading Y axis
                                        // labels shift the plot to the right.
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let x = value.location.x - geometry[plotFrame].origin.x
                                        if let position: Double = proxy.value(atX: x) {
                                            let clamped = max(0, min(entries.count - 1, Int(position.rounded())))
                                            if clamped != selectedIndex {
                                                selectedIndex = clamped
                                                HapticFeedback.playSelection()
                                            }
                                            showSelection = true
                                        }
                                    }
                                    .onEnded { _ in
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            showSelection = false
                                        }
                                        selectedIndex = nil
                                    }
                            )
                    }
                }
                .accessibilityLabel(settings.localizedString("A11Y_PRICE_CHART"))
                .padding(.leading, 10)
                .padding(.trailing, 20)
                .padding(.bottom, 4)

                if colorful {
                    levelLegend
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                } else {
                    Spacer().frame(height: 6)
                }
            }
        }
        .frame(width: chartSize.width)
        .frame(minHeight: minChartHeight, maxHeight: .infinity)
        .cardStyle(cornerRadius: 14)
    }

    /// Marks of the single-color chart, as it looked before price-level colors:
    /// bars/line in the text color, only the current interval highlighted.
    @ChartContentBuilder
    private func plainMarks(for entry: PriceChartEntry, isFifteenMin: Bool) -> some ChartContent {
        if settings.chartType == .bar {
            BarMark(
                x: .value("Time", entry.id),
                y: .value("Price", entry.price),
                width: isFifteenMin ? .fixed(2) : .automatic
            )
            .foregroundStyle(entry.isCurrent ? currentColor : barColor)
            .accessibilityLabel(accessibilityLabel(for: entry))
            .accessibilityValue(accessibilityValue(for: entry))
        } else {
            LineMark(
                x: .value("Time", entry.id),
                y: .value("Price", entry.price)
            )
            .foregroundStyle(barColor)
            .interpolationMethod(.catmullRom)
            .accessibilityLabel(accessibilityLabel(for: entry))
            .accessibilityValue(accessibilityValue(for: entry))

            AreaMark(
                x: .value("Time", entry.id),
                y: .value("Price", entry.price)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [barColor.opacity(0.3), barColor.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
            .accessibilityHidden(true)

            if entry.isCurrent {
                PointMark(
                    x: .value("Time", entry.id),
                    y: .value("Price", entry.price)
                )
                .foregroundStyle(currentColor)
                .symbolSize(60)
                .accessibilityHidden(true)
            }
        }
    }

    /// One-line legend explaining the bar colors. Kept deliberately small: the
    /// bars themselves carry the information, this just names the four levels.
    /// At accessibility sizes the four items no longer fit on one line, so they
    /// wrap into a 2×2 grid.
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

    private func accessibilityLabel(for entry: PriceChartEntry) -> String {
        entry.isCurrent ? "\(entry.timeLabel), \(settings.localizedString("LABEL_NOW"))" : entry.timeLabel
    }

    /// Price with unit, plus the level name so VoiceOver conveys what the bar
    /// color shows.
    private func accessibilityValue(for entry: PriceChartEntry) -> String {
        let price = String(format: viewModel.specifier, entry.price)
        guard let level = entry.level else { return price }
        return "\(price), \(settings.localizedString(level.localizationKey))"
    }

    private var titleText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM"
        formatter.locale = getLocale()
        return day == .tomorrow ? formatter.string(from: Date().dayAfter) : formatter.string(from: Date())
    }

    private func getLocale() -> Locale {
        switch settings.language {
        case .english: return Locale(identifier: "en_US")
        case .finnish: return Locale(identifier: "fi_FI")
        case .estonian: return Locale(identifier: "et_EE")
        case .russian: return Locale(identifier: "ru_RU")
        }
    }
}

struct ChartView_Previews: PreviewProvider {
    static var previews: some View {
        ChartView(day: Day.today, viewModel: Self.mockViewModel())
            .environmentObject(AppSettings())
    }

    static func mockViewModel() -> ChartViewModel {
        let vm = ChartViewModel()
        vm.isLoading = false
        vm.specifier = "%.2f snt/kWh"
        let hourlyPrices: [(String, Double)] = [
            ("00:00", 3.2), ("01:00", 0.2), ("02:00", -2.2), ("03:00", -3.0),
            ("04:00", 2.1), ("05:00", 2.6), ("06:00", 3.8), ("07:00", 5.4),
            ("08:00", 7.2), ("09:00", 8.5), ("10:00", 9.1), ("11:00", 8.8),
            ("12:00", 7.6), ("13:00", 6.9), ("14:00", 6.2), ("15:00", 5.8),
            ("16:00", 6.5), ("17:00", 8.9), ("18:00", 10.2), ("19:00", 9.4),
            ("20:00", 7.1), ("21:00", 5.3), ("22:00", 4.1), ("23:00", 3.5)
        ]
        vm.data = ChartData(values: hourlyPrices)
        vm.rawPricesMWh = hourlyPrices.map { $0.1 * 10 } // c/kWh -> €/MWh
        vm.minPrice = "2.10"
        vm.avgPrice = "5.93"
        vm.maxPrice = "10.20"
        return vm
    }
}

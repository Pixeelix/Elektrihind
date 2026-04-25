//
//  ChartView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 05.04.2023.
//

import SwiftUI
import Charts

struct ChartView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    var day: Day
    @ObservedObject var viewModel: ChartViewModel

    @State private var selectedIndex: Int? = nil
    @State private var showSelection: Bool = false

    private let currentColor = Color(hexString: "#FF964F")
    private var barColor: Color { Color.bluewWhiteText }

    init(day: Day, viewModel: ChartViewModel) {
        self.day = day
        self.viewModel = viewModel
    }

    private var chartSize: CGSize {
        CGSize(width: UIScreen.main.bounds.width * 0.9, height: ChartForm.barChartHeight)
    }

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ZStack {
                    Rectangle()
                        .fill(Color.contentBoxBackground)
                        .cornerRadius(14)
                    VStack {
                        ProgressView("Loading...")
                    }
                    .progressViewStyle(CircularProgressViewStyle(tint: .bluewWhiteText))
                    .foregroundColor(.bluewWhiteText)
                }
                .frame(width: chartSize.width, height: chartSize.height)
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

        return ZStack {
            Rectangle()
                .fill(Color.contentBoxBackground)
                .cornerRadius(14)

            VStack(alignment: .leading, spacing: 0) {
                // Header: selected value or chart type toggle
                HStack {
                    if showSelection, let idx = selectedIndex, idx >= 0, idx < entries.count {
                        Text("\(entries[idx].price, specifier: viewModel.specifier)")
                            .font(.headline)
                            .foregroundStyle(barColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(entries[idx].timeLabel)
                            .font(.headline)
                            .foregroundStyle(barColor)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text(titleText)
                            .font(.headline)
                            .foregroundStyle(barColor)
                        Spacer()
                    }
                    Button {
                        settings.chartType = (settings.chartType == .bar) ? .line : .bar
                    } label: {
                        Image(systemName: settings.chartType.systemImage)
                            .font(.title3)
                            .foregroundStyle(barColor)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Chart
                Chart {
                    ForEach(entries) { entry in
                        if settings.chartType == .bar {
                            BarMark(
                                x: .value("Time", entry.id),
                                y: .value("Price", entry.price),
                                width: settings.chartResolution == .fifteenMinutes ? .fixed(2) : .automatic
                            )
                            .foregroundStyle(entry.isCurrent ? currentColor : barColor)
                        } else {
                            LineMark(
                                x: .value("Time", entry.id),
                                y: .value("Price", entry.price)
                            )
                            .foregroundStyle(barColor)
                            .interpolationMethod(.catmullRom)

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

                            if entry.isCurrent {
                                PointMark(
                                    x: .value("Time", entry.id),
                                    y: .value("Price", entry.price)
                                )
                                .foregroundStyle(currentColor)
                                .symbolSize(60)
                            }
                        }
                    }

                    // Zero line — more prominent when negative prices exist
                    if hasNegative {
                        RuleMark(y: .value("Zero", 0))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            .foregroundStyle(Color.primary.opacity(0.5))
                    }

                    // Selected index indicator
                    if showSelection, let idx = selectedIndex, idx >= 0, idx < entries.count {
                        RuleMark(x: .value("Selected", idx))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            .foregroundStyle(currentColor.opacity(0.6))
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
                                let hour = Int(round(Double(idx) / Double(max(count - 1, 1)) * 24.0))
                                Text(String(format: "%02d", hour))
                                    .font(.system(size: 11, weight: .semibold))
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
                                    .font(.system(size: 9))
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
                                        let x = value.location.x
                                        if let index: Int = proxy.value(atX: x) {
                                            let clamped = max(0, min(entries.count - 1, index))
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
                .padding(.leading, 10)
                .padding(.trailing, 10)
                .padding(.bottom, 10)
            }
        }
        .frame(width: chartSize.width, height: chartSize.height)
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
        vm.minPrice = "2.10"
        vm.avgPrice = "5.93"
        vm.maxPrice = "10.20"
        return vm
    }
}

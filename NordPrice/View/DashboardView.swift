//
//  DashboardView.swift
//  NordPrice
//
//  iPad layout: today and tomorrow on one screen, one row per day. Each row has
//  a narrow column with the price cards and the chart beside it, so neither the
//  cards nor the chart stretch across the whole display.
//

import SwiftUI

struct DashboardView: View {
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var settings: AppSettings
    @StateObject private var todayViewModel = ChartViewModel()
    @StateObject private var tomorrowViewModel = ChartViewModel()
    @ScaledMetric(relativeTo: .body) private var sideColumnWidth: CGFloat = 340

    var body: some View {
        VStack(spacing: 20) {
            DayRow(title: settings.localizedString("TITLE_TODAYS_PRICE"), sideColumnWidth: sideColumnWidth) {
                CurrentPriceView()
                MinAvgMaxView(chartViewModel: todayViewModel)
            } chart: {
                ChartView(day: Day.today, viewModel: todayViewModel)
            }

            DayRow(title: settings.localizedString("TITLE_TOMORROWS_PRICE"), sideColumnWidth: sideColumnWidth) {
                if !tomorrowViewModel.missingData {
                    MinMaxRange(chartViewModel: tomorrowViewModel)
                    MinAvgMaxView(chartViewModel: tomorrowViewModel)
                }
            } chart: {
                if tomorrowViewModel.missingData {
                    Text(settings.localizedString("TEXT_TOMORROWS_PRICE_WILL_APEAR"))
                        .font(.title3.weight(.medium))
                        .foregroundColor(Color.bluewWhiteText)
                        .multilineTextAlignment(.center)
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cardStyle(cornerRadius: 14)
                } else {
                    ChartView(day: Day.tomorrow, viewModel: tomorrowViewModel)
                }
            }

            if !AppRuntimeConfiguration.hidesAdBanners {
                AdaptiveBannerAd(unitID: AdUnit.todayBanner)
            }
        }
        .environment(\.cardWidth, nil)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .scrollsAtAccessibilitySizes()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            todayViewModel.configure(settings: settings, day: Day.today)
            tomorrowViewModel.configure(settings: settings, day: Day.tomorrow)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                todayViewModel.loadChartData()
                tomorrowViewModel.loadChartData()
            } else if newPhase == .background {
                todayViewModel.cancelInFlight()
                tomorrowViewModel.cancelInFlight()
            }
        }
    }
}

/// One day of the dashboard: title and cards on the leading side, chart filling the rest.
private struct DayRow<Cards: View, ChartContent: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let sideColumnWidth: CGFloat
    @ViewBuilder let cards: Cards
    @ViewBuilder let chart: ChartContent
    @ScaledMetric(relativeTo: .title) private var titleFontSize: CGFloat = 28

    var body: some View {
        // At accessibility sizes the side column can't hold the cards next to the
        // chart, so the row stacks vertically (and the dashboard scrolls).
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))

        layout {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: titleFontSize, weight: .semibold))
                    .foregroundColor(Color.textOnBackground)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.leading, 4)
                cards
            }
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : sideColumnWidth,
                   alignment: .top)

            chart
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environmentObject(AppSettings())
            .previewDevice("iPad Pro 13-inch (M5)")
    }
}

//
//  TodayView.swift
//  NordPrice
//
//  Created by Martin Pihooja on 13.12.2021.
//

import SwiftUI

struct TodayView: View {
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var settings: AppSettings
    @StateObject private var chartViewModel = ChartViewModel()

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .center) {
                TitleView(title: settings.localizedString("TITLE_TODAYS_PRICE"))
                CurrentPriceView()
                    .padding(.bottom, 0)
                MinAvgMaxView(chartViewModel: chartViewModel)
                ChartView(day: Day.today, viewModel: chartViewModel)
                Spacer(minLength: 15)
                if !AppRuntimeConfiguration.hidesAdBanners {
                    AdaptiveBannerAd(unitID: AdUnit.todayBanner)
                        .padding(.bottom, 15)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            chartViewModel.configure(settings: settings, day: Day.today)
            prefetchTomorrow()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                chartViewModel.loadChartData()
                prefetchTomorrow()
            } else if newPhase == .background {
                chartViewModel.cancelInFlight()
            }
        }
    }

    /// Tomorrow's prices publish around 14:00 CET. Warm the cache for the next
    /// day even if the user never opens the Tomorrow tab, so the widget has
    /// something to read at midnight without needing the network. A cache hit
    /// returns without a request, so this is cheap to repeat on every foreground.
    private func prefetchTomorrow() {
        let region = settings.region
        Task.detached(priority: .background) {
            _ = try? await PriceRepository().loadFullDayData(Day.tomorrow, region: region)
        }
    }
}

struct TodayView_Previews: PreviewProvider {
    static var previews: some View {
        TodayView()
            .environmentObject(AppSettings())
    }
}

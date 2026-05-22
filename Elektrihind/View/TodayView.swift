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
                AdaptiveBannerAd(unitID: AdUnit.todayBanner)
                    .padding(.bottom, 15)
            }
        }
        .onAppear {
            chartViewModel.configure(settings: settings, day: Day.today)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                chartViewModel.loadChartData()
            } else if newPhase == .background {
                chartViewModel.cancelInFlight()
            }
        }
    }
}

struct TodayView_Previews: PreviewProvider {
    static var previews: some View {
        TodayView()
            .environmentObject(AppSettings())
    }
}

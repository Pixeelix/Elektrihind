//
//  TodayView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 13.12.2021.
//

import SwiftUI

struct TodayView: View {
    @Binding var tabSelection: Int
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var settings: AppSettings
    @StateObject private var chartViewModel = ChartViewModel()

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .center) {
                TitleView(title: settings.localizedString("TITLE_TODAYS_PRICE"))
                CurrentPriceView(tabSelection: $tabSelection)
                    .padding(.bottom, 0)
                MinAvgMaxView(chartViewModel: chartViewModel)
                ChartView(day: Day.today, viewModel: chartViewModel)
                Spacer()
                FixedBannerAd(unitID: "ca-app-pub-5431783362632568/4212512484")
                    .frame(height: 50)
                    .padding(.bottom, 25)
            }
        }
        .onAppear {
            chartViewModel.configure(settings: settings, day: Day.today)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                chartViewModel.loadChartData()
            }
        }
    }
}

struct TodayView_Previews: PreviewProvider {
    static var previews: some View {
        TodayView(tabSelection: .constant(0))
            .environmentObject(AppSettings())
    }
}

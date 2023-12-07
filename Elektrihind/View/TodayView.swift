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
    @EnvironmentObject var shared: Globals
    @StateObject private var chartViewModel = ChartViewModel()
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .center) {
                TitleView(title: shared.localizedString("TITLE_TODAYS_PRICE"))
                CurrentPriceView(tabSelection: $tabSelection)
                    .padding(.bottom, 0)
                MinAvgMaxView(day: .today)
                ChartView(day: .today, viewModel: chartViewModel)
                Spacer()
                BannerAd(unitID: "ca-app-pub-5431783362632568/4212512484").frame(maxHeight: 60)
                    .padding(.bottom, 15)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
        .onAppear {
            chartViewModel.setup(self.shared, day: .today)
            chartViewModel.loadChartData()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                chartViewModel.setup(self.shared, day: .today)
                chartViewModel.loadChartData()
            }
        }
    }
    
}

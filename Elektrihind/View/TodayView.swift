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
                BannerAd(unitID: "ca-app-pub-5431783362632568/9156829008")
                    .frame(maxHeight: 60)
                    .padding(.bottom, 25)
            }
        }
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

// PreviewProvider for TodayView
struct TodayView_Previews: PreviewProvider {
    static var previews: some View {
        TodayView(tabSelection: .constant(0))
            .environmentObject(Globals()) // Inject Globals instance for testing
    }
}

//
//  TomorrowView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 13.12.2021.
//

import SwiftUI

struct TomorrowView: View {
    @Binding var tabSelection: Int
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var shared: Globals
    @StateObject private var chartViewModel = ChartViewModel()

    var body: some View {
        VStack {
            TitleView(title: shared.localizedString("TITLE_TOMORROWS_PRICE"))
            
            if shared.missingTomorrowData {
                noDataView
            } else {
                dataView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear(perform: loadChartData)
        .onChange(of: scenePhase, perform: handleScenePhaseChange)
    }

    // View when no data for tomorrow
    private var noDataView: some View {
        VStack {
            Text(shared.localizedString("TEXT_TOMORROWS_PRICE_WILL_APEAR"))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(EdgeInsets(top: 20, leading: 10, bottom: 20, trailing: 10))
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // View when tomorrow's data is available
    private var dataView: some View {
        VStack {
            MinMaxRange(tabSelection: $tabSelection)
                .padding(.bottom, 0)
            
            MinAvgMaxView(day: .tomorrow)
            
            ChartView(day: .tomorrow, viewModel: chartViewModel)
            
            Spacer()
            
            BannerAd(unitID: "ca-app-pub-5431783362632568/3104542071")
                .frame(maxHeight: 60)
                .padding(.bottom, 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Load chart data when the view appears
    private func loadChartData() {
        chartViewModel.setup(shared, day: .tomorrow)
        chartViewModel.loadChartData()
    }

    // Reload chart data when the app becomes active
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .active {
            chartViewModel.setup(shared, day: .tomorrow)
            chartViewModel.loadChartData()
        }
    }
}

struct TomorrowView_Previews: PreviewProvider {
    static var previews: some View {
        TomorrowView(tabSelection: .constant(0))
            .environmentObject(Globals())
    }
}

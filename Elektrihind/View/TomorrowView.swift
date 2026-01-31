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
        .onChange(of: shared.chartResolution) { _ in
            chartViewModel.setup(shared, day: Day.tomorrow)
            chartViewModel.loadChartData()
        }
    }

    // View when no data for tomorrow
    private var noDataView: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Top half
                VStack {
                    Spacer()
                    Text(shared.localizedString("TEXT_TOMORROWS_PRICE_WILL_APEAR"))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 10)
                    Spacer()
                }
                .frame(height: geo.size.height * 0.4)

                // Bottom half (ad near bottom)
                VStack {
                    Spacer()
                    AdaptiveBannerAd(unitID: "ca-app-pub-5431783362632568/8076084809")
                        .padding(.bottom, 25)
                }
                .frame(height: geo.size.height * 0.6)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }


    // View when tomorrow's data is available
    private var dataView: some View {
        VStack {
            MinMaxRange(tabSelection: $tabSelection)
                .padding(.bottom, 0)
            
            MinAvgMaxView(day: Day.tomorrow)
            
            ChartView(day: Day.tomorrow, viewModel: chartViewModel)
            
            Spacer()
            
            FixedBannerAd(unitID: "ca-app-pub-5431783362632568/3104542071")
                .frame(height: 50)
                .padding(.bottom, 25)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Load chart data when the view appears
    private func loadChartData() {
        chartViewModel.setup(shared, day: Day.tomorrow)
        chartViewModel.loadChartData()
    }

    // Reload chart data when the app becomes active
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .active {
            chartViewModel.setup(shared, day: Day.tomorrow)
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

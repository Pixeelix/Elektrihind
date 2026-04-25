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
    @EnvironmentObject var settings: AppSettings
    @StateObject private var chartViewModel = ChartViewModel()

    var body: some View {
        VStack {
            TitleView(title: settings.localizedString("TITLE_TOMORROWS_PRICE"))

            if chartViewModel.missingData {
                noDataView
            } else {
                dataView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            chartViewModel.configure(settings: settings, day: Day.tomorrow)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                chartViewModel.loadChartData()
            } else if newPhase == .background {
                chartViewModel.cancelInFlight()
            }
        }
    }

    private var noDataView: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack {
                    Spacer()
                    Text(settings.localizedString("TEXT_TOMORROWS_PRICE_WILL_APEAR"))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 10)
                    Spacer()
                }
                .frame(height: geo.size.height * 0.85)

                VStack {
                    Spacer()
                    AdaptiveBannerAd(unitID: AdUnit.tomorrowNoDataBanner)
                        .padding(.bottom, 15)
                }
                .frame(height: geo.size.height * 0.15)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var dataView: some View {
        VStack {
            MinMaxRange(tabSelection: $tabSelection, chartViewModel: chartViewModel)
                .padding(.bottom, 0)

            MinAvgMaxView(chartViewModel: chartViewModel)
            ChartView(day: Day.tomorrow, viewModel: chartViewModel)
            Spacer(minLength: 15)
            AdaptiveBannerAd(unitID: AdUnit.tomorrowDataBanner)
                .padding(.bottom, 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TomorrowView_Previews: PreviewProvider {
    static var previews: some View {
        TomorrowView(tabSelection: .constant(0))
            .environmentObject(AppSettings())
    }
}

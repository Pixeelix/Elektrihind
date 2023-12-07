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
        HStack(alignment: .top) {
            if shared.missingTomorrowData {
                VStack(alignment: .center) {
                    TitleView(title: shared.localizedString("TITLE_TOMORROWS_PRICE"))
                    Text(shared.localizedString("TEXT_TOMORROWS_PRICE_WILL_APEAR"))
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                        .font(.system(size: 18, weight: .medium, design: .default))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(EdgeInsets(top: 20, leading: 10, bottom: 20, trailing: 10))
                    Spacer()
                }
            } else {
                VStack(alignment: .center) {
                    TitleView(title: shared.localizedString("TITLE_TOMORROWS_PRICE"))
                    MinMaxRange(tabSelection: $tabSelection)
                        .padding(.bottom, 0)
                    MinAvgMaxView(day: .tomorrow)
                    ChartView(day: .tomorrow, viewModel: chartViewModel)
                    Spacer()
                    BannerAd(unitID: "ca-app-pub-5431783362632568/3104542071").frame(maxHeight: 60)
                        .padding(.bottom, 15)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
        .onAppear {
            chartViewModel.setup(self.shared, day: .tomorrow)
            chartViewModel.loadChartData()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                chartViewModel.setup(self.shared, day: .tomorrow)
                chartViewModel.loadChartData()
            }
        }
    }
}

struct TomorrowView_Previews: PreviewProvider {
    static var previews: some View {
        TomorrowView(tabSelection: .constant(0))
    }
}

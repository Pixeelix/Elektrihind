//
//  TodayView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 13.12.2021.
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject var shared: Globals
    @State var exampleCounter: Int = 0
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .center) {
                TitleView(title: shared.localizedString("TITLE_TODAYS_PRICE"))
                CurrentPriceView()
                    .padding(.bottom, UIScreen.is1stGenIphone || UIScreen.isIphone8 ? 10 : 50)
                TodayChartView()
                Spacer()
                BannerAd().frame(maxHeight: 60)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
    }
    
}

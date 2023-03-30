//
//  TomorrowView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 13.12.2021.
//

import SwiftUI

struct TomorrowView: View {
    @EnvironmentObject var shared: Globals
    
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
                    BannerAd().frame(maxHeight: 60)
                }
            } else {
                VStack(alignment: .center) {
                    TitleView(title: shared.localizedString("TITLE_TOMORROWS_PRICE"))
                    MinMaxRange()
                        .padding(.bottom, UIScreen.is1stGenIphone || UIScreen.isIphone8 ? 10 : 50)
                    TomorrowChartView()
                    Spacer()
                    BannerAd().frame(maxHeight: 60)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
    }
}

struct TomorrowView_Previews: PreviewProvider {
    static var previews: some View {
        TomorrowView()
    }
}

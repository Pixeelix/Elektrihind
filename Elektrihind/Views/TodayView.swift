//
//  TodayView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 13.12.2021.
//

import SwiftUI

struct TodayView: View {
    @State private var currentPriceData: PriceData?
    @State var priceData: [(String, Double)] = []
    @State var dataLastLoadedHour: Int? = nil
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .center) {
                TitleView(title: "Tänane hind")
                CurrentPriceView(priceData: currentPriceData)
                    .padding(.bottom, 50)
                ChartView(day: .today, data: priceData)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
        .onAppear() {
            if let dataLastLoadedHour = dataLastLoadedHour,
               dataLastLoadedHour == Calendar.current.component(.hour, from: Date()) {
                return
            } else {
                Network().loadCurrentPrice { data in
                    self.currentPriceData = data
                }
                Network().loadEstDayData(.today) { data in
                    self.priceData = data
                }
                self.dataLastLoadedHour = Calendar.current.component(.hour, from: Date())
            }
        }
    }
}

struct TodayView_Previews: PreviewProvider {
    static var previews: some View {
        TodayView()
    }
}

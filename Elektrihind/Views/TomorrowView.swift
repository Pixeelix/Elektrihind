//
//  TomorrowView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 13.12.2021.
//

import SwiftUI

struct TomorrowView: View {
    @State private var currentPriceData: PriceData?
    @State var priceData: [(String, Double)] = []
    @State var missingData = true
    @State var dataLastLoadedHour: Int? = nil
    
    var body: some View {
        HStack(alignment: .top) {
            if missingData {
                VStack(alignment: .center) {
                    TitleView(title: "Homne hind")
                    
                    Text("Homne hinnainfo on saadaval alates 15:00")
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                        .font(.system(size: 18, weight: .medium, design: .default))
                        .foregroundColor(.white)
                        .padding(EdgeInsets(top: 20, leading: 10, bottom: 20, trailing: 10))
                }
            } else {
                VStack(alignment: .center) {
                    TitleView(title: "Homne hind")
                    NextDayMinMaxRange(data: priceData)
                        .padding(.bottom, 50)
                    ChartView(day: .tomorrow, data: priceData)
                }
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
                Network().loadFullDayData(.tomorrow) { data in
                    missingData = data.count <= 2
                    self.priceData = data
                }
                self.dataLastLoadedHour = Calendar.current.component(.hour, from: Date())
            }
        }
    }
}

struct TomorrowView_Previews: PreviewProvider {
    static var previews: some View {
        TomorrowView()
    }
}

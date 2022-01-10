//
//  TodayView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 13.12.2021.
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject var shared: Globals
    @State var dataLastLoadedHour: Int? = nil
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .center) {
                TitleView(title: localizedString("TITLE_TODAYS_PRICE"))
                CurrentPriceView()
                    .padding(.bottom, 50)
                ChartView(day: .today)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
        .onAppear() {
            loadDataIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            loadDataIfNeeded()
        }
    }
    
    func loadDataIfNeeded() {
        if let dataLastLoadedHour = dataLastLoadedHour,
           dataLastLoadedHour == Calendar.current.component(.hour, from: Date()) {
            return
        } else {
            Network().loadCurrentPrice { data in
                shared.currentPrice = data
            }
            Network().loadFullDayData(.today) { data in
                shared.todayFullDayData = data
            }
            self.dataLastLoadedHour = Calendar.current.component(.hour, from: Date())
        }
    }
    
}

struct TodayView_Previews: PreviewProvider {
    static var previews: some View {
        TodayView()
    }
}

//
//  TodayView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 13.12.2021.
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject var shared: Globals
    @State var dataLastLoaded: Date? = nil
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
//                Button("Uuenda") {
//                    self.exampleCounter += 1
//                    let decodedExample: NordPoolCountriesData = Bundle.main.decode(file: "fullDayExampleData\(exampleCounter).json")
//                    var fullDayData = [PriceData]()
//                    for data in decodedExample.data.ee {
//                        fullDayData.append(data)
//                    }
//                    shared.todayFullDayData = fullDayData
//                    shared.chartViewUpdateId += 1
//                }
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
        shared.chartViewUpdateId += 1 // Used to update ChartView as without id, the graph bars are not updating automatically
        if let dataLastLoaded = dataLastLoaded {
            let lastLoadedHour = Calendar.current.component(.hour, from: Date())
            let currentHour = Calendar.current.component(.hour, from: dataLastLoaded)
            if lastLoadedHour != currentHour ||
                dataLastLoaded.addingTimeInterval(3600) < Date() {
                loadData()
            } else {
                return
            }
        } else {
            loadData()
        }
    }
    
    func loadData() {
        Network().loadCurrentPrice { data in
            shared.currentPrice = data
        }
        Network().loadFullDayData(.today) { data in
            shared.todayFullDayData = data
        }
        self.dataLastLoaded = Date()
        
    }
    
}
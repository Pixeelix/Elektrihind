//
//  TomorrowView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 13.12.2021.
//

import SwiftUI

struct TomorrowView: View {
    @EnvironmentObject var shared: Globals
    @State var missingData = true
    @State var dataLastLoaded: Date? = nil
    
    var body: some View {
        HStack(alignment: .top) {
            if missingData {
                VStack(alignment: .center) {
                    TitleView(title: shared.localizedString("TITLE_TOMORROWS_PRICE"))
                    Text(shared.localizedString("TEXT_TOMORROWS_PRICE_WILL_APEAR"))
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                        .font(.system(size: 18, weight: .medium, design: .default))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(EdgeInsets(top: 20, leading: 10, bottom: 20, trailing: 10))
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
        .onAppear() {
            loadDataIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            loadDataIfNeeded()
        }
    }
    func loadDataIfNeeded() {
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
        Network().loadFullDayData(.tomorrow) { data in
            missingData = data.count <= 2
            shared.tomorrowFullDayData = data
        }
        self.dataLastLoaded = Date()
    }
}

struct TomorrowView_Previews: PreviewProvider {
    static var previews: some View {
        TomorrowView()
    }
}

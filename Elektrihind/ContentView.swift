//
//  ContentView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var shared: Globals
    @State private var tabBarSelection = 0
    @ObservedObject var networkManager = NetworkManager()
    
    init() {
        UITabBar.appearance().backgroundColor = UIColor(named: "tabBarBackground")
    }
    
    var body: some View {
        if networkManager.isConnected {
            TabView(selection: $tabBarSelection) {
                TodayView()
                    .tag(0)
                    .background(backGroundColor().edgesIgnoringSafeArea(.all))
                TomorrowView()
                    .tag(1)
                    .background(backGroundColor().edgesIgnoringSafeArea(.all))
    //          Text("Hea teada")
    //              .tag(2)
    //              .background(backGroundColor().edgesIgnoringSafeArea(.all))
                SettingsView()
                    .tag(2)
                    .background(backGroundColor().edgesIgnoringSafeArea(.all))
            }
            .onAppear() {
                shared.getSavedSettings()
            }
            .overlay(TabBarView(selection: $tabBarSelection), alignment: .bottom)
        } else {
            ZStack {
                backGroundColor().ignoresSafeArea()
                
                VStack {
                    Image(systemName: "wifi.slash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .foregroundColor(.white)
                    
                    Text(shared.localizedString("TEXT_CONNECTION_LOST"))
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding()
                    
                    Button {
                        self.settingsOpener()
                    } label: {
                        Text(shared.localizedString("TITLE_OPEN_SETTINGS"))
                            .padding()
                            .font(.headline)
                            .foregroundColor(Color("blueGrayText"))
                    }
                    .frame(width: 160)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .padding()
                }
            }
        }
       
    }
    
    private func settingsOpener(){
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
    
    func backGroundColor() -> LinearGradient {
       return LinearGradient(gradient: Gradient(colors: [Color("backgroundTop"), Color("backgroundBottom")]), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct TitleView: View {
    var title: String
    var body: some View {
        Text(title)
            .font(.system(size: 32, weight: .medium, design: .default))
            .foregroundColor(.white)
            .padding(EdgeInsets(top: 10, leading: 20, bottom: 20, trailing: 20))
    }
}

struct CurrentPriceView: View {
    let dateFormatter = DateFormatter()
    @EnvironmentObject var shared: Globals
    
    init() {
        dateFormatter.timeZone = TimeZone(abbreviation: "EET")
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "HH:mm"
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if let price = shared.currentPrice?.price,
               let priceWithTax = shared.includeTax ? price * 1.2 : price,
               let timeStamp = shared.currentPrice?.timestamp,
               let formattedPrice = shared.numberFormatter.string(from: NSNumber(value: priceWithTax / shared.divider)) {
                let date = Date(timeIntervalSince1970: timeStamp)
                let strDate = dateFormatter.string(from: date)
                
                HStack(alignment: .top) {
                    Spacer()
                    Text(strDate)
                        .font(.system(size: 300))
                        .minimumScaleFactor(0.01)
                }
                .frame(height: 22)
                .padding(.top, 8)
                .padding(.trailing, 10)
                
                VStack {
                    Text(formattedPrice)
                        .font(.system(size: 300, weight: .medium))
                        .minimumScaleFactor(0.01)
                }
                .frame(height: UIScreen.isSmallScreen ? 56 : 82)
                .padding(.top, -12)
                
                VStack {
                    Text(shared.localizedString(shared.unit))
                        .font(.system(size: 24, weight: .medium))
                }
               Spacer()
            }
        }
        .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.isSmallScreen ? 120 : 140)
        .background(Color("contentBoxBackground"))
        .foregroundColor(Color("blueWhiteText"))
        .cornerRadius(20)
    }
}

struct NextDayMinMaxRange: View {
    @EnvironmentObject var shared: Globals
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            VStack {
                Text("\(shared.minNextDayPrice) - \(shared.maxNextDayPrice)")
                    .font(.system(size: 300, weight: .medium))
                    .minimumScaleFactor(0.01)
                    .lineLimit(1)
            }
            .frame(height: UIScreen.isSmallScreen ? 42 : 68)
            .padding(.horizontal, 30)
            
            VStack {
                Text(shared.localizedString(shared.unit))
                    .font(.system(size: 24, weight: .medium))
            }
        }
        .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.isSmallScreen ? 120 : 140)
        .background(Color("contentBoxBackground"))
        .foregroundColor(Color("blueWhiteText"))
        .cornerRadius(20)
        .padding(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
    }
}

struct ChartView: View {
    @EnvironmentObject var shared: Globals
    private var day: Day = .today
    var todayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM"
        formatter.locale = shared.language == .english ? Locale(identifier: "en_US") : Locale(identifier: "et_EE")
        return formatter.string(from: Date())
    }
    var tomorrowDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM"
        formatter.locale = shared.language == .english ? Locale(identifier: "en_US") : Locale(identifier: "et_EE")
        return formatter.string(from: Date().dayAfter)
    }
    let myCustomStyle = ChartStyle(backgroundColor: .white, accentColor: .blue, secondGradientColor: .blue, textColor: .blue, legendTextColor: .gray, dropShadowColor: .clear)
    let myCustomDarkModeStyle = ChartStyle(backgroundColor: .gray, accentColor: .white, secondGradientColor: .white, textColor: .white, legendTextColor: .white, dropShadowColor: .clear)
    
    init(day: Day) {
        self.day = day
        myCustomStyle.darkModeStyle = myCustomDarkModeStyle
        UIPageControl.appearance().currentPageIndicatorTintColor = .blue
        UIPageControl.appearance().pageIndicatorTintColor = UIColor.black.withAlphaComponent(0.2)
    }
    
    var body: some View {
        let title = day == .tomorrow ? tomorrowDate : todayDate
        VStack {
            if day == .today {
                BarChartView(data: ChartData(values: shared.todayFullDayChartData), title: title, legend: "Quarterly", style: myCustomStyle, form: ChartForm.extraLarge, valueSpecifier: "%.\(shared.minFractionDigits)f \(shared.localizedString(shared.unit))", animatedToBack: false)
            } else if day == .tomorrow {
                BarChartView(data: ChartData(values: shared.tomorrowFullDayChartData), title: title, legend: "Quarterly", style: myCustomStyle, form: ChartForm.extraLarge, valueSpecifier: "%.\(shared.minFractionDigits)f \(shared.localizedString(shared.unit))", animatedToBack: false)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(ColorScheme.allCases, id: \.self) {
            ContentView().preferredColorScheme($0)
        }
    }
}

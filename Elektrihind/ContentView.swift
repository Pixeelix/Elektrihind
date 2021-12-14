//
//  ContentView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import SwiftUI
import SwiftUICharts

struct ContentView: View {
    @State private var tabBarSelection = 0
    
    var body: some View {
        ZStack {
            BackgroundView(topColor: Color("backgroundTop"), bottomColor: Color("backgroundBottom"))
            VStack {
                TabView(selection: $tabBarSelection) {
                    TodayView()
                        .tag(0)
                    TomorrowView()
                        .tag(1)
//                    Text("Hea teada")
//                        .tag(2)
                    SettingsView()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                TabBarView(selection: $tabBarSelection)
                    .background(Color("tabBarBackground"))
            }
        }
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
    var priceData: PriceData?
    let dateFormatter: DateFormatter
    private let numberFormater = NumberFormatter()
    
    init(priceData: PriceData?) {
        self.priceData = priceData
        dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "EET") //Set timezone that you want
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "HH:mm" //Specify your format that you want
        
        numberFormater.decimalSeparator = ","
        numberFormater.maximumIntegerDigits = 4
        numberFormater.minimumFractionDigits = 4
    }
    
    var body: some View {
        VStack(alignment: .center) {
            if let price = priceData?.price,
               let timeStamp = priceData?.timestamp,
               let formattedPrice = numberFormater.string(from: NSNumber(value: price / 1000)) {
                
                let date = Date(timeIntervalSince1970: timeStamp)
                let strDate = dateFormatter.string(from: date)
                
                HStack(alignment: .top) {
                    Spacer()
                    Text(strDate)
                        .padding(.top, 10)
                        .padding(.trailing, 10)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text(formattedPrice)
                        .font(.system(size: 72, weight: .medium))
                    
                    Text("€/kWh")
                        .font(.system(size: 38, weight: .medium))
                }
                .offset(x: 0, y: -12)
            }
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .background(Color("contentBoxBackground"))
        .foregroundColor(Color("blueWhiteText"))
        .cornerRadius(20)
        .padding(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
    }
}

struct NextDayMinMaxRange: View {
    private var minPrice: String = ""
    private var maxPrice: String = ""
    
    private let numberFormater = NumberFormatter()
    
    init(data: [(String, Double)]) {
        numberFormater.decimalSeparator = ","
        numberFormater.maximumIntegerDigits = 4
        numberFormater.minimumFractionDigits = 4
        
        var pricesArray: [Double] = []
        for dataPoint in data {
            pricesArray.append(dataPoint.1)
        }
        
        minPrice = numberFormater.string(from: NSNumber(value: pricesArray.min() ?? 0)) ?? ""
        maxPrice = numberFormater.string(from: NSNumber(value: pricesArray.max() ?? 1)) ?? ""
    }
    
    var body: some View {
        VStack(alignment: .center) {
            VStack {
                Text("\(minPrice) - \(maxPrice)")
                    .font(.system(size: 42, weight: .medium))
                
                Text("€/kWh")
                    .font(.system(size: 38, weight: .medium))
            }
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .background(Color("contentBoxBackground"))
        .foregroundColor(Color("blueWhiteText"))
        .cornerRadius(20)
        .padding(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
    }
}

struct ChartView: View {
    private var day: Day = .today
    private var data: [(String, Double)]
    let dateFormatter: DateFormatter
    var todayDate: String {
        return dateFormatter.string(from: Date())
    }
    var tomorrowDate: String {
        return dateFormatter.string(from: Date().dayAfter)
    }
    let myCustomStyle = ChartStyle(backgroundColor: .white, accentColor: .blue, secondGradientColor: .blue, textColor: .blue, legendTextColor: .gray, dropShadowColor: .clear)
    let myCustomDarkModeStyle = ChartStyle(backgroundColor: .gray, accentColor: .white, secondGradientColor: .white, textColor: .white, legendTextColor: .white, dropShadowColor: .clear)
    
    init(day: Day, data: [(String, Double)]) {
        self.day = day
        self.data = data
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM"
        myCustomStyle.darkModeStyle = myCustomDarkModeStyle
        
        UIPageControl.appearance().currentPageIndicatorTintColor = .blue
        UIPageControl.appearance().pageIndicatorTintColor = UIColor.black.withAlphaComponent(0.2)
    }
    
    var body: some View {
        let title = day == .tomorrow ? tomorrowDate : todayDate
        VStack {
            BarChartView(data: ChartData(values: data), title: title, legend: "Quarterly", style: myCustomStyle, form: ChartForm.extraLarge, valueSpecifier: "%.4f €/kWh", animatedToBack: false)
        }
    }
}

struct BackgroundView: View {
    var topColor: Color
    var bottomColor: Color
    var body: some View {
        LinearGradient(gradient: Gradient(colors: [topColor, bottomColor]), startPoint: .topLeading, endPoint: .bottomTrailing).edgesIgnoringSafeArea(.all)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ZStack {
                LottieView(fileName: "mainPageLoader")
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

//
//  ContentView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import SwiftUI
import SwiftUICharts

struct ContentView: View {
    @State private var isLoading = false
    @State var currentPriceData: PriceData?
    
    var body: some View {
        ZStack {
            BackgroundView(topColor: .blue, bottomColor: .white)
                VStack(alignment: .center) {
                    TitleView(title: "Elektrihind")
                    CurrentPriceView(priceData: currentPriceData)
                    LazyHStack {
                        PageView()
                    }
                }
            if isLoading {
             //   LoadingView()
            }
        }.onAppear() {
            isLoading = true
            Network().loadCurrentPrice { data in
                self.currentPriceData = data
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isLoading = false
                }
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
    
    init(priceData: PriceData?) {
        self.priceData = priceData
        dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "EET") //Set timezone that you want
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "HH:mm" //Specify your format that you want
    }
    
    var body: some View {
        VStack(alignment: .center) {
            if let price = priceData?.price,
               let timeStamp = priceData?.timestamp {
                let formattedPrice = String(format: "%.4f", price / 1000)
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
                    Text("\(formattedPrice)")
                        .font(.system(size: 72, weight: .medium))
                    
                    Text("€/kWh")
                        .font(.system(size: 38, weight: .medium))
                }
                .offset(x: 0, y: -12)
            }
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .background(.white)
        .foregroundColor(.blue)
        .cornerRadius(10)
        .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
    }
}

struct PageView: View {
    @State var estonianDayPrice: [(String, Double)] = []
    
    let dateFormatter: DateFormatter
    var todayDate: String {
        return dateFormatter.string(from: Date())
    }
    var tomorrowDate: String {
        return dateFormatter.string(from: Date().dayAfter)
    }
    let myChartStyle = ChartStyle(backgroundColor: .white, accentColor: .blue, gradientColor: GradientColor(start: .blue, end: .blue), textColor: .blue, legendTextColor: .gray, dropShadowColor: .gray)
    
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM"
        
        UIPageControl.appearance().currentPageIndicatorTintColor = .blue
        UIPageControl.appearance().pageIndicatorTintColor = UIColor.black.withAlphaComponent(0.2)
    }
    
    var body: some View {
        TabView {
            ForEach(0..<2) { i in
                ZStack {
                    if i == 0 {
                        let firstPrie = estonianDayPrice.count > 1 ? estonianDayPrice[0].1 : 0
                        BarChartView(data: ChartData(values: estonianDayPrice), title: "\(firstPrie)", legend: "Quarterly", style: myChartStyle, form: ChartForm.extraLarge, valueSpecifier: "%.4f")
                            .onAppear() {
                                Network().loadEstDayData(.today) { data in
                                    self.estonianDayPrice = data
                                }
                            }
                        
                                //                        LineView(data: estonianDayPrice, title: "Täna", legend: "\(todayDate)", style: myChartStyle)
                                //                            .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                                //                            .onAppear() {
                                //                                Network().loadEstDayData(.today) { data in
                                //                                    self.estonianDayPrice = data
                                //                                }
//                            }
                    } else if i == 1 {
//                        LineView(data: estonianDayPrice, title: "Homme", legend: "\(tomorrowDate)", style: myChartStyle)
//                            .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
//                            .onAppear() {
//                                Network().loadEstDayData(.tomorrow) { data in
//                                    self.estonianDayPrice = data
//                                }
//                            }
                    }
                    
                }.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(width: UIScreen.main.bounds.width, height: 410)
        .tabViewStyle(PageTabViewStyle())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.portraitUpsideDown)
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

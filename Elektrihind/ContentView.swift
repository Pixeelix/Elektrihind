//
//  ContentView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import SwiftUI
import SwiftUICharts

struct ContentView: View {
    @State var currentPrice = 0.0
    
    var body: some View {
        ZStack {
            BackgroundView(topColor: .blue, bottomColor: .white)
            VStack(alignment: .center) {
                TitleView(title: "Hetke hind")
                CurrentPriceView(price: currentPrice)
                
                LazyHStack {
                    PageView()
                }
            }
            
        }.onAppear() {
            Network().loadCurrentPrice { data in
                self.currentPrice = data.price
            }
        }
    }
}

struct PageView: View {
    @State var estonianDayPrice: [Double] = [8, 2, 4, 6, 12, 9, 2]
    
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
                        LineView(data: estonianDayPrice, title: "Täna", legend: "\(todayDate)", style: myChartStyle)
                            .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                            .onAppear() {
                                Network().loadEstDayData(.today) { data in
                                    self.estonianDayPrice = data
                                }
                            }
                    } else if i == 1 {
                        LineView(data: estonianDayPrice, title: "Homme", legend: "\(tomorrowDate)", style: myChartStyle)
                            .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                            .onAppear() {
                                Network().loadEstDayData(.tomorrow) { data in
                                    self.estonianDayPrice = data
                                }
                            }
                    }
                    
                }.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(width: UIScreen.main.bounds.width, height: 410)
        .tabViewStyle(PageTabViewStyle())
        .background(.white)
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

struct CurrentPriceView: View {
    var price: Double
    var body: some View {
        VStack(alignment: .center) {
            let formattedPrice = String(format: "%.2f", price)
            Text("\(formattedPrice)")
                .font(.system(size: 72, weight: .medium))
            Text("€/MWh")
                .font(.system(size: 38, weight: .medium))
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background(.white)
        .foregroundColor(.blue)
        .cornerRadius(10)
        .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
    }
}

struct TitleView: View {
    var title: String
    var body: some View {
        Text(title)
            .font(.system(size: 32, weight: .medium, design: .default))
            .foregroundColor(.white)
            .padding()
    }
}

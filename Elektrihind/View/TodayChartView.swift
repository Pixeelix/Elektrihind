//
//  TodayChartView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 30.09.2022.
//

import SwiftUI

struct TodayChartView: View {
    @EnvironmentObject var shared: Globals
    let myCustomStyle = ChartStyle(backgroundColor: .white, accentColor: .blue, secondGradientColor: .blue, textColor: .blue, legendTextColor: .gray, dropShadowColor: .clear)
    let myCustomDarkModeStyle = ChartStyle(backgroundColor: .gray, accentColor: .white, secondGradientColor: .white, textColor: .white, legendTextColor: .white, dropShadowColor: .clear)
    
    init() {
        myCustomStyle.darkModeStyle = myCustomDarkModeStyle
        UIPageControl.appearance().currentPageIndicatorTintColor = .blue
        UIPageControl.appearance().pageIndicatorTintColor = UIColor.black.withAlphaComponent(0.2)
    }
    
    var body: some View {
        VStack {
            BarChartView(data: ChartData(values: shared.todayFullDayChartData), day: .today, legend: "Quarterly", style: myCustomStyle, form: ChartForm.extraLarge, valueSpecifier: "%.\(shared.minFractionDigits)f \(shared.localizedString(shared.unit))", animatedToBack: false)
        }
    }
}

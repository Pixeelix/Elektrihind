//
//  ChartView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 05.04.2023.
//

import SwiftUI

struct ChartView: View {
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var shared: Globals
    @StateObject private var viewModel = ChartViewModel()
    var day: Day
    let style = ChartStyle(backgroundColor: .white, accentColor: .blue, secondGradientColor: .blue, textColor: .blue, legendTextColor: .gray, dropShadowColor: .clear)
    let darkStyle = ChartStyle(backgroundColor: .gray, accentColor: .white, secondGradientColor: .white, textColor: .white, legendTextColor: .white, dropShadowColor: .clear)
    
    init(day: Day) {
        self.day = day
        style.darkModeStyle = darkStyle
        UIPageControl.appearance().currentPageIndicatorTintColor = .blue
        UIPageControl.appearance().pageIndicatorTintColor = UIColor.black.withAlphaComponent(0.2)
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else {
                BarChartView(data: viewModel.data, day: self.day, legend: viewModel.legend, style: style, form: viewModel.form, valueSpecifier: viewModel.specifier, animatedToBack: false)
            }
        }
        .onAppear {
            viewModel.setup(self.shared, day: day)
            viewModel.loadChartData()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                viewModel.setup(self.shared, day: day)
                viewModel.loadChartData()
            }
        }
    }
}

struct ChartView_Previews: PreviewProvider {
    static var previews: some View {
        ChartView(day: .today)
    }
}

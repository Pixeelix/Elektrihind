//
//  ChartView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 05.04.2023.
//

import SwiftUI

struct ChartView: View {
    @EnvironmentObject var shared: Globals
    var day: Day
    var viewModel: ChartViewModel
    let style = ChartStyle(backgroundColor: .white, accentColor: .blue, secondGradientColor: .blue, textColor: .blue, legendTextColor: .gray, dropShadowColor: .clear)
    let darkStyle = ChartStyle(backgroundColor: .gray, accentColor: .white, secondGradientColor: .white, textColor: .white, legendTextColor: .white, dropShadowColor: .clear)
    
    init(day: Day, viewModel: ChartViewModel) {
        self.day = day
        self.viewModel = viewModel
        style.darkModeStyle = darkStyle
        UIPageControl.appearance().currentPageIndicatorTintColor = .blue
        UIPageControl.appearance().pageIndicatorTintColor = UIColor.black.withAlphaComponent(0.2)
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ZStack {
                    Rectangle()
                        .fill(Color.contentBoxBackground)
                        .cornerRadius(20)
                        .padding()
                    Spacer()
                    VStack {
                        ProgressView("Loading...")
                    }
                    .progressViewStyle(CircularProgressViewStyle(tint: .bluewWhiteText))
                    .foregroundColor(.bluewWhiteText)
                    .padding()
                    Spacer()
                }
                
            } else {
                BarChartView(data: viewModel.data, day: self.day, legend: viewModel.legend, style: style, form: viewModel.form, valueSpecifier: viewModel.specifier, animatedToBack: false)
            }
        }
    }
}

struct ChartView_Previews: PreviewProvider {
    static var previews: some View {
        ChartView(day: .today, viewModel: ChartViewModel())
    }
}

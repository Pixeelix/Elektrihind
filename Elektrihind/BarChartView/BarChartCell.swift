//
//  BarChartCell.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 20.01.2022.
//

import SwiftUI

public struct BarChartCell : View {
    @Environment(\.scenePhase) var scenePhase
    var value: Double
    var index: Int = 0
    var width: Float
    var numberOfDataPoints: Int
    var day: Day
    var cellWidth: Double {
        return Double(width)/(Double(numberOfDataPoints) * 1.5)
    }
    let currentHour = Calendar.current.component(.hour, from: Date())
    var accentColor: Color
    var originalGradient: GradientColor
    @State var gradient: GradientColor?
    @State var scaleValue: Double = 0
    @Binding var touchLocation: CGFloat
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(gradient: gradient?.getGradient() ?? GradientColor(start: accentColor, end: accentColor).getGradient(), startPoint: .bottom, endPoint: .top))
            }
            .frame(width: CGFloat(self.cellWidth))
            .scaleEffect(CGSize(width: 1, height: self.scaleValue), anchor: .bottom)
            .onAppear(){
                self.scaleValue = self.value
                self.gradient = getGradientColor()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    self.gradient = getGradientColor()
                }
            }
        .animation(Animation.spring().delay(self.touchLocation < 0 ?  Double(self.index) * 0.04 : 0))
    }
    
    func getGradientColor() -> GradientColor {
        if day == .today {
            return index == currentHour ? GradientColor(start: Color(hexString: "#FF964F"), end: Color(hexString: ":#FF964F")) : originalGradient
        } else {
            return originalGradient
        }
    }
}

#if DEBUG
struct ChartCell_Previews : PreviewProvider {
    static var previews: some View {
        BarChartCell(value: Double(0.75), width: 320, numberOfDataPoints: 12, day: .today, accentColor: Colors.OrangeStart, originalGradient: GradientColor(start: Color.red, end: Color.blue), touchLocation: .constant(-1))
    }
}
#endif

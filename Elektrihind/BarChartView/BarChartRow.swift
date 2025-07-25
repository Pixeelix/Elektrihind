//
//  BarChartRow.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 20.01.2022.
//

import SwiftUI

public struct BarChartRow : View {
    @Environment(\.scenePhase) var scenePhase
    var data: [Double]
    var day: Day
    var accentColor: Color
    var gradient: GradientColor?
    var maxValue: Double {
        guard let max = data.max() else {
            return 1
        }
        return max != 0 ? max : 1
    }
    @Binding var touchLocation: CGFloat
    public var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: (geometry.frame(in: .local).width-22)/CGFloat(self.data.count * 3)){
                ForEach(0..<self.data.count, id: \.self) { i in
                    BarChartCell(value: self.normalizedValue(index: i),
                                 index: i,
                                 width: Float(geometry.frame(in: .local).width - 22),
                                 numberOfDataPoints: self.data.count,
                                 day: day,
                                 accentColor: self.accentColor,
                                 gradient: getGradientFor(i),
                                 touchLocation: self.$touchLocation)
                        .scaleEffect(self.touchLocation > CGFloat(i)/CGFloat(self.data.count) && self.touchLocation < CGFloat(i+1)/CGFloat(self.data.count) ? CGSize(width: 1.4, height: 1.1) : CGSize(width: 1, height: 1), anchor: .bottom)
                        .animation(.spring())
                    
                }
            }
            .padding([.top, .leading, .trailing], 10)
        }
    }
    
    func getGradientFor(_ index: Int) -> GradientColor{
        let currentHour = Calendar.current.component(.hour, from: Date())
        if day == .today {
            if index == currentHour {
                return GradientColor(start: Color(hexString: "#FF964F"), end: Color(hexString: ":#FF964F"))
            } else {
                return gradient ?? GradientColor(start: Color.blue, end: Color.blue)
            }
        } else {
            return gradient ?? GradientColor(start: Color.blue, end: Color.blue)
        }
    }
    
    func normalizedValue(index: Int) -> Double {
        return Double(self.data[index])/Double(self.maxValue)
    }
}

#if DEBUG
struct ChartRow_Previews : PreviewProvider {
    static var previews: some View {
        Group {
            BarChartRow(data: [0], day: .today, accentColor: Colors.OrangeStart, touchLocation: .constant(-1))
            BarChartRow(data: [8,23,54,32,12,37,7], day: .today, accentColor: Colors.OrangeStart, touchLocation: .constant(-1))
        }
    }
}
#endif

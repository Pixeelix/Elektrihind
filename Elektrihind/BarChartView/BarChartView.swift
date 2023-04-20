//
//  BarChartView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 20.01.2022.

import SwiftUI

struct BarChartView : View {
    @EnvironmentObject var shared: Globals
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    private var data: ChartData
    private var title: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM"
        formatter.locale = getLocale()
        return day == .tomorrow ? formatter.string(from: Date().dayAfter) : formatter.string(from: Date())
    }
    public var legend: String?
    public var style: ChartStyle
    public var darkModeStyle: ChartStyle
    public var formSize: CGSize
    public var dropShadow: Bool
    public var cornerImage: Image?
    public var valueSpecifier:String
    public var animatedToBack: Bool
    public var day: Day
    
    @State private var touchLocation: CGFloat = -1.0
    @State private var showValue: Bool = false
    @State private var showLabelValue: Bool = false
    @State private var currentValue: Double = 0 {
        didSet{
            if(oldValue != self.currentValue && self.showValue) {
                HapticFeedback.playSelection()
            }
        }
    }
    var isFullWidth:Bool {
        return self.formSize == ChartForm.large
    }
    init(data: ChartData, day: Day, legend: String? = nil, style: ChartStyle = Styles.barChartStyleOrangeLight, form: CGSize? = ChartForm.medium, dropShadow: Bool? = true, cornerImage:Image? = Image(systemName: "waveform.path.ecg"), valueSpecifier: String? = "%.1f", animatedToBack: Bool = false) {
        self.data = data
        self.day = day
        self.legend = legend
        self.style = style
        self.darkModeStyle = style.darkModeStyle != nil ? style.darkModeStyle! : Styles.barChartStyleOrangeDark
        self.formSize = form!
        self.dropShadow = dropShadow!
        self.cornerImage = cornerImage
        self.valueSpecifier = valueSpecifier!
        self.animatedToBack = animatedToBack
    }
    
    var body: some View {
        ZStack{
            Rectangle()
                .fill(self.colorScheme == .dark ? self.darkModeStyle.backgroundColor : self.style.backgroundColor)
                .cornerRadius(20)
                .shadow(color: self.style.dropShadowColor, radius: self.dropShadow ? 8 : 0)
            VStack(alignment: .leading){
                HStack{
                    if(!showValue){
                        Text(self.title)
                            .font(.headline)
                            .foregroundColor(self.colorScheme == .dark ? self.darkModeStyle.textColor : self.style.textColor)
                    } else {
                        HStack {
                            Text("\(self.currentValue, specifier: self.valueSpecifier)")
                                .font(.headline)
                                .foregroundColor(self.colorScheme == .dark ? self.darkModeStyle.textColor : self.style.textColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text(self.getCurrentValue()!.0)
                                .font(.headline)
                                .foregroundColor(self.colorScheme == .dark ? self.darkModeStyle.textColor : self.style.textColor)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    Spacer()
//                    self.cornerImage
//                        .imageScale(.large)
//                        .foregroundColor(self.colorScheme == .dark ? self.darkModeStyle.legendTextColor : self.style.legendTextColor)
                }.padding()
                BarChartRow(data: data.points.map{$0.1},
                            day: day, accentColor: self.colorScheme == .dark ? self.darkModeStyle.accentColor : self.style.accentColor,
                            gradient: self.colorScheme == .dark ? self.darkModeStyle.gradientColor : self.style.gradientColor,
                            touchLocation: self.$touchLocation)
                if self.legend != nil  && self.formSize == ChartForm.medium && !self.showLabelValue{
//                    Text(self.legend!)
//                        .font(.headline)
//                        .foregroundColor(self.colorScheme == .dark ? self.darkModeStyle.legendTextColor : self.style.legendTextColor)
//                        .padding()
                                
                } else if (self.data.valuesGiven && self.getCurrentValue() != nil) {
//                    LabelView(arrowOffset: self.getArrowOffset(touchLocation: self.touchLocation),
//                              title: .constant(self.getCurrentValue()!.0))
//                        .offset(x: self.getLabelViewOffset(touchLocation: self.touchLocation), y: -6)
//                        .foregroundColor(self.colorScheme == .dark ? self.darkModeStyle.legendTextColor : self.style.legendTextColor)
                    let timesArray = ["00:00", "04:00", "08:00", "12:00", "16:00", "20:00", "23:00"]
                    let shotTimesArray = ["00:00", "08:00", "12:00", "18:00", "23:00"]
                    if !UIScreen.is1stGenIphone {
                    HStack {
                            ForEach(timesArray, id: \.self) {
                                Text($0)
                                    .scaledToFit()
                                    .minimumScaleFactor(0.01)
                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                    .foregroundColor(Color("grayWhiteText"))
                                    .frame(maxWidth: .infinity)
                            }
                    }
                    .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 20)
                    .offset(y: -5)
                    } else {
                        HStack {
                                ForEach(shotTimesArray, id: \.self) {
                                    Text($0)
                                        .scaledToFit()
                                        .minimumScaleFactor(0.01)
                                        .font(.system(size: 12, weight: .semibold, design: .default))
                                        .foregroundColor(Color("grayWhiteText"))
                                        .frame(maxWidth: .infinity)
                                }
                        }
                        .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 20)
                        .offset(y: -5)
                    }
                }
                
            }
        }
        .frame(minWidth:self.formSize.width,
                maxWidth: self.isFullWidth ? .infinity : self.formSize.width,
                minHeight:self.formSize.height,
                maxHeight:self.formSize.height)
        .gesture(DragGesture()
                .onChanged({ value in
                    self.touchLocation = value.location.x / self.formSize.width
                    self.showValue = true
                    self.currentValue = self.getCurrentValue()?.1 ?? 0
                    if(self.data.valuesGiven && self.formSize == ChartForm.medium) {
                        self.showLabelValue = true
                    }
                })
                .onEnded({ value in
                    if animatedToBack {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            withAnimation(Animation.easeOut(duration: 1)) {
                                self.showValue = false
                                self.showLabelValue = false
                                self.touchLocation = -1
                            }
                        }
                    } else {
                        self.showValue = false
                        self.showLabelValue = false
                        self.touchLocation = -1
                    }
                })
        )
            .gesture(TapGesture())
    }
    
    func getArrowOffset(touchLocation:CGFloat) -> Binding<CGFloat> {
        let realLoc = (self.touchLocation * self.formSize.width) - 50
        if realLoc < 10 {
            return .constant(realLoc - 10)
        }else if realLoc > self.formSize.width-110 {
            return .constant((self.formSize.width-110 - realLoc) * -1)
        } else {
            return .constant(0)
        }
    }
    
    func getLabelViewOffset(touchLocation:CGFloat) -> CGFloat {
        return min(self.formSize.width-110,max(10,(self.touchLocation * self.formSize.width) - 50))
    }
    
    func getCurrentValue() -> (String,Double)? {
        guard self.data.points.count > 0 else { return nil}
        let index = max(0,min(self.data.points.count-1,Int(floor((self.touchLocation*self.formSize.width)/(self.formSize.width/CGFloat(self.data.points.count))))))
        return self.data.points[index]
    }
    
    func getLocale() -> Locale {
        switch shared.language {
        case .english:
            return Locale(identifier: "en_US")
        case .finnish:
            return Locale(identifier: "fi_FI")
        case .estonian:
            return Locale(identifier: "et_EE")
        case .russian:
            return Locale(identifier: "ru_RU")
        }
    }
}

#if DEBUG
struct BarChartView_Previews : PreviewProvider {
    static var previews: some View {
        BarChartView(data: TestData.values, day: .today, legend: "Quarterly", form: ChartForm.extraLarge, valueSpecifier: "%.4f €/kWh")
    }
}
#endif

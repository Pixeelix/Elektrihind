//
//  GoodToKnowView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 06.10.2022.
//

import SwiftUI

struct GoodToKnowView: View {
    @EnvironmentObject var shared: Globals
    @State var selectedTime = Date()
    @State private var powerConsumption: String = "600"
    
    
    var body: some View {
        Background {
            GeometryReader { geometry in
                VStack {
                    TitleView(title: shared.localizedString("TITLE_HELPER"))
                    
                    VStack(alignment: .center, spacing: 10) {
                        HStack {
                            Text("Seadme energiakulu")
                                .font(.system(size: 20))
                                .minimumScaleFactor(0.01)
                                .lineLimit(1)
                                .layoutPriority(1)
                                .padding(.leading)
                            Spacer()
                            TextField("600", text: $powerConsumption) {
                                self.endEditing()
                            }
                                .padding(5)
                                .accentColor(.white)
                                .background(RoundedRectangle(cornerRadius: 7).fill(Color.gray.opacity(0.30)))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: geometry.size.width * 0.3)
                                
                            Text("W")
                                .padding(.trailing)
                        }
                        .frame(height: UIScreen.isSmallScreen ? 60 : 60)
                        .background(Color("contentBoxBackground"))
                        .foregroundColor(Color("blueWhiteText"))
                        .cornerRadius(10)
                        .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                        
                        HStack {
                            DatePicker("Seadme kasutusaeg", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .font(.system(size: 20))
                                .minimumScaleFactor(0.01)
                                .lineLimit(1)
                                .layoutPriority(1)
                                .environment(\.locale, Locale.init(identifier: "et"))
                                .padding(.horizontal)
                        }
                        .frame(height: UIScreen.isSmallScreen ? 60 : 60)
                        .background(Color("contentBoxBackground"))
                        .foregroundColor(Color("blueWhiteText"))
                        .cornerRadius(10)
                        .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))

                        HStack {
                            Text("Hetke kulu tunnis:")
                                .font(.system(size: 20))
                                .minimumScaleFactor(0.01)
                                .lineLimit(1)
                                .layoutPriority(1)
                                .padding(.leading)
                            Spacer()
                            Text(calculatedCost())
                                .font(.title2)
                                .padding(.trailing)
                        }
                        .frame(height: UIScreen.isSmallScreen ? 60 : 60)
                        .background(Color("contentBoxBackground"))
                        .foregroundColor(Color("blueWhiteText"))
                        .cornerRadius(10)
                        .padding(EdgeInsets(top: 30, leading: 8, bottom: 0, trailing: 8))
                    }
                }

            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
        .foregroundColor(.white)
        .background(backGroundColor().edgesIgnoringSafeArea(.all))
        .onAppear {
            if let midnight = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date()) {
                selectedTime = midnight
            }
        }
        .onTapGesture {
            self.endEditing()
        }
    }
    
    private func endEditing() {
           UIApplication.shared.endEditing()
       }
    
    func calculatedCost() -> String {
        if let price = shared.currentPrice?.price,
        let powerConsumptionNumber = Double(powerConsumption) {
            let priceWithTax = shared.includeTax ? price * 1.2 : price
            let wattPrice = priceWithTax * 0.000001
            let formatter = NumberFormatter()
                formatter.numberStyle = .currency
            
                formatter.locale = Locale(identifier: "et_EE")
                return formatter.string(from: NSNumber(value: wattPrice * powerConsumptionNumber)) ?? "0,00 €"
        } else {
            return "0,00 €"
        }
    }
    
}

struct Background<Content: View>: View {
    private var content: Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content()
    }

    var body: some View {
        Color.clear
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        .overlay(content)
    }
}

struct GoodToKnowView_Previews: PreviewProvider {
    static let shared = Globals()
    static var previews: some View {
        GoodToKnowView().environmentObject(shared)
    }
}



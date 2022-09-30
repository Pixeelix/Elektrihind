//
//  CurrentPriceView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 29.09.2022.
//

import SwiftUI

struct CurrentPriceView: View {
    @EnvironmentObject var shared: Globals
    let dateFormatter = DateFormatter()
    
    init() {
        dateFormatter.timeZone = TimeZone(abbreviation: "EET")
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "HH:mm"
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if let price = shared.currentPrice?.price,
               let priceWithTax = shared.includeTax ? price * 1.2 : price,
               let timeStamp = shared.currentPrice?.timestamp,
               let formattedPrice = shared.numberFormatter.string(from: NSNumber(value: priceWithTax / shared.divider)) {
                let date = Date(timeIntervalSince1970: timeStamp)
                let strDate = dateFormatter.string(from: date)
                
                HStack(alignment: .top) {
                    Spacer()
                    Text(strDate)
                        .font(.system(size: 300))
                        .minimumScaleFactor(0.01)
                }
                .frame(height: 22)
                .padding(.top, 8)
                .padding(.trailing, 10)
                
                VStack {
                    Text(formattedPrice)
                        .font(.system(size: 300, weight: .medium))
                        .minimumScaleFactor(0.01)
                }
                .frame(height: UIScreen.isSmallScreen ? 56 : 82)
                .padding(.top, -12)
                
                VStack {
                    Text(shared.localizedString(shared.unit))
                        .font(.system(size: 24, weight: .medium))
                }
               Spacer()
            }
        }
        .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.isSmallScreen ? 120 : 140)
        .background(Color("contentBoxBackground"))
        .foregroundColor(Color("blueWhiteText"))
        .cornerRadius(20)
    }
}

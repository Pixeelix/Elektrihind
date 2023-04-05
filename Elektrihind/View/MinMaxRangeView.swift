//
//  MinMaxRangeView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 29.09.2022.
//

import SwiftUI

struct MinMaxRange: View {
    @EnvironmentObject var shared: Globals
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            VStack {
                Text("\(shared.minNextDayPrice) - \(shared.maxNextDayPrice)")
                    .font(.system(size: 300, weight: .medium))
                    .minimumScaleFactor(0.01)
                    .lineLimit(1)
            }
            .frame(height: UIScreen.is1stGenIphone ? 42 : 68)
            .padding(.horizontal, 30)
            
            VStack {
                Text(shared.localizedString(shared.unit))
                    .font(.system(size: 24, weight: .medium))
            }
        }
        .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.is1stGenIphone ? 120 : 140)
        .background(Color.contentBoxBackground)
        .foregroundColor(Color.bluewWhiteText)
        .cornerRadius(20)
        .padding(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
    }
}

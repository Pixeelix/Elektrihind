//
//  MinAvgMaxView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 10.10.2023.
//

import SwiftUI

struct MinAvgMaxView: View {
    @EnvironmentObject var shared: Globals
    var day: Day
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .center) {
                    Text(shared.localizedString("TITLE_MIN"))
                        .font(.system(size: 18, weight: .medium))
                    Text(day == .today ? "\(shared.minDayPrice)" : "\(shared.minNextDayPrice)")
                        .font(.system(size: 18, weight: .bold))
                }
                Spacer()
                VStack(alignment: .center) {
                    Text(shared.localizedString("TITLE_AVG"))
                        .font(.system(size: 18, weight: .medium))
                    Text(day == .today ? "\(shared.avgDayPrice)" : "\(shared.avgNextDayPrice)")
                        .font(.system(size: 18, weight: .bold))
                }
                Spacer()
                VStack(alignment: .center) {
                    Text(shared.localizedString("TITLE_MAX"))
                        .font(.system(size: 18, weight: .medium))
                    Text(day == .today ? "\(shared.maxDayPrice)" : "\(shared.maxNextDayPrice)")
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .padding(.top, 8)
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.bottom, 8)
        }
        .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.is1stGenIphone ? 50 : 60)
        .background(Color.contentBoxBackground)
        .foregroundColor(Color.bluewWhiteText)
        .cornerRadius(10)
    }
}

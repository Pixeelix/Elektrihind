//
//  TitleView.swift
//  NordPrice
//
//  Created by Martin Pihooja on 29.09.2022.
//

import SwiftUI

struct TitleView: View {
    var title: String
    @ScaledMetric(relativeTo: .largeTitle) private var fontSize: CGFloat = 32
    var body: some View {
        Text(title)
            .font(.system(size: fontSize, weight: .medium, design: .default))
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            .foregroundColor(Color.textOnBackground)
            .padding(EdgeInsets(top: 10, leading: 20, bottom: 12, trailing: 20))
    }
}

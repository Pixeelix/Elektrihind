//
//  MinAvgMaxView.swift
//  NordPrice
//
//  Created by Martin Pihooja on 10.10.2023.
//

import SwiftUI

struct MinAvgMaxView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var chartViewModel: ChartViewModel
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 18

    private var items: [(key: String, value: String)] {
        [("TITLE_MIN", chartViewModel.minPrice),
         ("TITLE_AVG", chartViewModel.avgPrice),
         ("TITLE_MAX", chartViewModel.maxPrice)]
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Three columns don't fit at accessibility sizes: one row per value.
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.key) { item in
                        HStack {
                            label(item.key)
                            Spacer()
                            value(item.value)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } else {
                HStack(alignment: .top) {
                    ForEach(Array(items.enumerated()), id: \.element.key) { index, item in
                        if index > 0 { Spacer() }
                        VStack(alignment: .center) {
                            label(item.key)
                            value(item.value)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .padding(.top, 8)
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.bottom, 8)
        .cardWidth()
        .frame(minHeight: UIScreen.is1stGenIphone ? 50 : 60)
        .foregroundColor(Color.bluewWhiteText)
        .cardStyle(cornerRadius: 14)
    }

    private func label(_ key: String) -> some View {
        Text(settings.localizedString(key))
            .font(.system(size: fontSize, weight: .medium))
            .foregroundColor(Color.cardLabelText)
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold))
    }
}

//
//  MinMaxRangeView.swift
//  NordPrice
//
//  Created by Martin Pihooja on 29.09.2022.
//

import SwiftUI

struct MinMaxRange: View {
    @EnvironmentObject var settings: AppSettings
    @ObservedObject var chartViewModel: ChartViewModel
    @State private var showRegionPicker = false
    @ScaledMetric(relativeTo: .largeTitle) private var priceHeight: CGFloat = UIScreen.isTallScreen ? 62 : 52
    @ScaledMetric(relativeTo: .title2) private var unitFontSize: CGFloat = 24

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(alignment: .top) {
                RegionFlagButton(region: settings.region) {
                    showRegionPicker = true
                }
                Spacer()
            }
            .frame(minHeight: 22)
            .padding(.top, 8)
            .padding(.leading, 10)
            .padding(.trailing, 10)

            VStack {
                Text("\(chartViewModel.minPrice) - \(chartViewModel.maxPrice)")
                    .font(.system(size: 300, weight: .medium))
                    .minimumScaleFactor(0.01)
                    .lineLimit(1)
            }
            .frame(height: priceHeight)
            .padding(.horizontal, 30)
            .padding(.top, -12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(settings.localizedString("A11Y_PRICE_RANGE"))
            .accessibilityValue("\(chartViewModel.minPrice) – \(chartViewModel.maxPrice) \(settings.localizedString(settings.unit))")

            VStack {
                Text(settings.localizedString(settings.unit))
                    .font(.system(size: unitFontSize, weight: .medium))
            }
            .padding(.bottom, 8)
            .accessibilityHidden(true)
        }
        .cardWidth()
        .frame(minHeight: UIScreen.isTallScreen ? 120 : 100, alignment: .top)
        .heroCardStyle(cornerRadius: 16)
        .tint(.brand)
        .confirmationDialog(settings.localizedString("TITLE_REGION"), isPresented: $showRegionPicker, titleVisibility: .visible) {
            ForEach(Region.allRegions, id: \.self) { region in
                Button(settings.localizedString(region.name)) {
                    settings.region = region
                }
            }
            Button(settings.localizedString("BUTTON_CANCEL"), role: .cancel) {}
        }
    }
}

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

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(alignment: .top) {
                Button {
                    showRegionPicker = true
                } label: {
                    Image(settings.region.rawValue)
                        .resizable()
                }
                .frame(width: 30, height: 22)
                .cornerRadius(6)
                .shadow(radius: 5)
                Spacer()
            }
            .frame(height: 22)
            .padding(.top, 8)
            .padding(.leading, 10)
            .padding(.trailing, 10)

            VStack {
                Text("\(chartViewModel.minPrice) - \(chartViewModel.maxPrice)")
                    .font(.system(size: 300, weight: .medium))
                    .minimumScaleFactor(0.01)
                    .lineLimit(1)
            }
            .frame(height: UIScreen.isTallScreen ? 62 : 52)
            .padding(.horizontal, 30)
            .padding(.top, -12)

            VStack {
                Text(settings.localizedString(settings.unit))
                    .font(.system(size: 24, weight: .medium))
            }
            Spacer()
        }
        .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.isTallScreen ? 120 : 100)
        .background(Color.contentBoxBackground)
        .foregroundColor(Color.bluewWhiteText)
        .tint(.blue)
        .cornerRadius(12)
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

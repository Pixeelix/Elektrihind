//
//  CurrentPriceView.swift
//  NordPrice
//
//  Created by Martin Pihooja on 29.09.2022.
//

import SwiftUI

struct CurrentPriceView: View {
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var settings: AppSettings
    @StateObject private var viewModel = CurrentPriceViewModel()
    @State private var showRegionPicker = false
    /// Grows with Dynamic Type; the price text itself fits whatever height this gives.
    @ScaledMetric(relativeTo: .largeTitle) private var priceHeight: CGFloat = UIScreen.isTallScreen ? 62 : 52
    @ScaledMetric(relativeTo: .title2) private var unitFontSize: CGFloat = 24

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(alignment: .top) {
                RegionFlagButton(region: settings.region) {
                    showRegionPicker = true
                }
                Spacer()
                Text(viewModel.currentPriceTimestamp)
                    .font(.subheadline)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 22)
            .padding(.top, 8)
            .padding(.leading, 10)
            .padding(.trailing, 10)

            VStack {
                Text(viewModel.currentPrice)
                    .font(.system(size: 300, weight: .medium))
                    .minimumScaleFactor(0.01)
            }
            .frame(height: priceHeight)
            .padding(.top, -12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(settings.localizedString("TEXT_CURRENT_PRICE"))
            .accessibilityValue("\(viewModel.currentPrice) \(viewModel.unit), \(viewModel.currentPriceTimestamp)")

            VStack {
                Text(viewModel.unit)
                    .font(.system(size: unitFontSize, weight: .medium))
            }
            .padding(.bottom, 8)
            .accessibilityHidden(true)
        }
        .frame(width: UIScreen.main.bounds.width * 0.9)
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
        .onAppear {
            viewModel.configure(settings: settings)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                viewModel.loadCurrentPrice()
            } else if newPhase == .background {
                viewModel.cancelInFlight()
            }
        }
    }
}

/// Region flag that opens the region picker. The flag stays small, but the tap
/// target is padded out to 44pt and VoiceOver reads the region name.
struct RegionFlagButton: View {
    @EnvironmentObject var settings: AppSettings
    let region: Region
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(region.rawValue)
                .resizable()
                .frame(width: 30, height: 22)
                .cornerRadius(6)
                .shadow(radius: 5)
                .padding(.vertical, 11)
                .padding(.trailing, 14)
                .contentShape(Rectangle())
        }
        .padding(.vertical, -11)
        .accessibilityLabel(settings.localizedString(region.name))
        .accessibilityHint(settings.localizedString("A11Y_CHANGE_REGION"))
    }
}

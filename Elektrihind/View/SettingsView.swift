//
//  SettingsView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 14.12.2021.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    let unitsArray = ["€/kWh", "€/MWh", "cent/kWh"]
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

    init() {
        setupAppearance()
    }

    private func setupAppearance() {
        let appearance = UINavigationBar.appearance()
        UITableView.appearance().backgroundColor = .clear
        appearance.barTintColor = .clear
        appearance.backgroundColor = .clear
        appearance.setBackgroundImage(UIImage(), for: .default)
        appearance.shadowImage = UIImage()
        appearance.tintColor = .blue
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .center) {
                TitleView(title: settings.localizedString("LABEL_SETTINGS"))

                Form {
                    generalSettingsSection
                    payAttentionSection
                    appInfoSection
                    adSection
                }
                .tint(.blue)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var generalSettingsSection: some View {
        Section(header: Text(settings.localizedString("TITLE_GENERAL"))) {
            Picker(settings.localizedString("TITLE_LANGUAGE"), selection: $settings.language) {
                ForEach(Language.allLanguages, id: \.self) { language in
                    Text(settings.localizedString(language.name))
                }
            }
            Picker(settings.localizedString("TITLE_REGION"), selection: $settings.region) {
                ForEach(Region.allRegions, id: \.self) { region in
                    Text(settings.localizedString(region.name))
                }
            }
            Picker(settings.localizedString("TITLE_UNIT"), selection: $settings.unit) {
                ForEach(unitsArray, id: \.self) {
                    Text(settings.localizedString($0))
                }
            }
            Toggle(isOn: $settings.includeTax) {
                Text(settings.localizedString("TITLE_INCLUDE_TAX"))
            }
            HStack {
                Text(settings.localizedString("TITLE_VAT"))
                Spacer()
                Text(settings.taxPercentage)
            }

            Toggle(isOn: $settings.alwaysOnDisplay) {
                Text(settings.localizedString("TITLE_ALWAYS_ON_DISPLAY"))
            }

            Picker(settings.localizedString("TITLE_CHART_RESOLUTION"), selection: $settings.chartResolution) {
                ForEach(ChartResolution.allCases, id: \.self) { resolution in
                    Text(resolution.label)
                }
            }
        }
    }
    
    private var payAttentionSection: some View {
        Section(header: Text(settings.localizedString("TITLE_PAY_ATTENTION"))) {
            Text(settings.localizedString("TEXT_INFORMATION_ABOUT_APP"))
            Text(settings.localizedString("TEXT_IFORMATION_ABOUT_MARKET_TIME_UNIT"))
        }
    }

    private var appInfoSection: some View {
        Section(header: Text(settings.localizedString("TITLE_APP_INFO"))) {
            HStack {
                Text(settings.localizedString("TITLE_VERSION"))
                Spacer()
                Text(appVersion ?? "")
            }
        }
    }
    
    private var adSection: some View {
        Section() {
            AdaptiveBannerAd(unitID: AdUnit.settingsBanner)
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }
}



struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(AppSettings())
    }
}

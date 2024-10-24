//
//  SettingsView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 14.12.2021.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var shared: Globals
    let unitsArray = ["€/kWh", "€/MWh", "cent/kWh"]
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

    init() {
        setupAppearance()
    }
    
    // Extracted UI appearance customization into a separate function
    private func setupAppearance() {
        let appearance = UINavigationBar.appearance()
        UITableView.appearance().backgroundColor = .clear
        appearance.barTintColor = .clear
        appearance.backgroundColor = .clear
        appearance.setBackgroundImage(UIImage(), for: .default)
        appearance.shadowImage = UIImage()
    }
    
    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                ios16SettingsView
            } else {
                ios15SettingsView
            }
        }
    }
    
    // Separate View for iOS 16+ using modern APIs
    @available(iOS 16.0, *)
    private var ios16SettingsView: some View {
        VStack(alignment: .center) {
            TitleView(title: shared.localizedString("LABEL_SETTINGS"))

            Form {
                generalSettingsSection
                appInfoSection
                payAttentionSection
            }
            .scrollContentBackground(.hidden)  // iOS 16-specific to hide background in the form
        }
    }
    
    // Separate View for older iOS versions
    private var ios15SettingsView: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                VStack {
                    Form {
                        generalSettingsSection
                        appInfoSection
                        payAttentionSection
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitle(shared.localizedString("LABEL_SETTINGS"))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TitleView(title: shared.localizedString("LABEL_SETTINGS"))
                        .padding(.top, 11)
                }
            }
        }
    }
    
    // Reusable view sections
    private var generalSettingsSection: some View {
        Section(header: Text(shared.localizedString("TITLE_GENERAL"))) {
            Picker(shared.localizedString("TITLE_LANGUAGE"), selection: $shared.language) {
                ForEach(Language.allLanguages, id: \.self) { language in
                    Text(shared.localizedString(language.name))
                }
            }
            Picker(shared.localizedString("TITLE_REGION"), selection: $shared.region) {
                ForEach(Region.allRegions, id: \.self) { region in
                    Text(shared.localizedString(region.name))
                }
            }
            .onChange(of: shared.region) { _ in
                shared.todayDataUpdateMandatory = true
                shared.tomorrowDataUpdateMandatory = true
            }
            Picker(shared.localizedString("TITLE_UNIT"), selection: $shared.unit) {
                ForEach(unitsArray, id: \.self) {
                    Text(shared.localizedString($0))
                }
            }
            Toggle(isOn: $shared.includeTax) {
                Text(shared.localizedString("TITLE_INCLUDE_TAX"))
            }
            HStack {
                Text(shared.localizedString("TITLE_VAT"))
                Spacer()
                Text(shared.taxPercentage)
            }
            // New Toggle for "Always On Display"
            Toggle(isOn: $shared.alwaysOnDisplay) {
                Text(shared.localizedString("TITLE_ALWAYS_ON_DISPLAY"))
            }
        }
    }
    
    private var appInfoSection: some View {
        Section(header: Text(shared.localizedString("TITLE_APP_INFO"))) {
            HStack {
                Text(shared.localizedString("TITLE_VERSION"))
                Spacer()
                Text(appVersion ?? "")
            }
        }
    }
    
    private var payAttentionSection: some View {
        Section(header: Text(shared.localizedString("TITLE_PAY_ATTENTION"))) {
            HStack {
                Text(shared.localizedString("TEXT_INFORMATION_ABOUT_APP"))
            }
        }
    }
    
    // Background gradient for older iOS versions
    private var backgroundGradient: some View {
        LinearGradient(gradient: Gradient(colors: [Color("backgroundTop"), Color("backgroundBottom")]),
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(Globals())
    }
}

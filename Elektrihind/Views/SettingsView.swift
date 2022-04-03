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
    
    init(){
        UITableView.appearance().backgroundColor = .clear
        UINavigationBar.appearance().barTintColor = .clear
        UINavigationBar.appearance().backgroundColor = .clear
        UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .default)
        UINavigationBar.appearance().shadowImage = UIImage()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color("backgroundTop"), Color("backgroundBottom")]), startPoint: .topLeading, endPoint: .bottomTrailing).edgesIgnoringSafeArea(.all)
                Form {
                    Section (header: Text(shared.localizedString("TITLE_GENERAL"))){
                        Picker(shared.localizedString("TITLE_LANGUAGE"), selection: $shared.language) {
                            ForEach(Language.allLanguages, id: \.self) { language in
                                Text(language.fullName)
                            }
                        }
                        Picker(shared.localizedString("TITLE_UNIT"), selection: $shared.unit) {
                            ForEach(unitsArray, id: \.self) {
                                Text(shared.localizedString($0))
                            }
                        }
                        Toggle(isOn: $shared.includeTax) {
                            Text(shared.localizedString("TITLE_INCLUDE_TAX"))
                        }
                    }
                    Section(header: Text(shared.localizedString("TITLE_APP_INFO"))) {
                        HStack {
                            Text(shared.localizedString("TITLE_VERSION"))
                            Spacer()
                            Text(appVersion ?? "")
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitle(shared.localizedString("LABEL_SETTINGS"))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack() {
                        Spacer()
                        TitleView(title: shared.localizedString("LABEL_SETTINGS"))
                            .padding(.top, 11)
                    }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}


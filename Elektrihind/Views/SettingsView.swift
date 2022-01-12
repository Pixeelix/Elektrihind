//
//  SettingsView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 14.12.2021.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var shared: Globals
    let unitsArray = ["€/kWh", "€/MWh", "senti/kWh"]
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
                    Section (header: Text("Üldine")){
                        Picker(shared.localizedString("TITLE_LANGUAGE"), selection: $shared.language) {
                            ForEach(Language.allLanguages, id: \.self) {
                                Text($0.rawValue)
                            }
                        }
                        Picker("Ühik", selection: $shared.unit) {
                            ForEach(unitsArray, id: \.self) {
                                Text($0)
                            }
                        }
                    }
                    Section(header: Text("Rakenduse info")) {
                        HStack {
                            Text("Versioon")
                            Spacer()
                            Text(appVersion ?? "")
                        }
                    }
                }
               
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitle("Seaded")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 10) {
                        Text("")
                        TitleView(title: shared.localizedString("LABLE_SETTINGS"))
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
    

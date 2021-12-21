//
//  SettingsView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 14.12.2021.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var globals: Globals
    let unitsArray = ["€/kWh", "€/MWh", "senti/kWh"]
    
    init(){
        UITableView.appearance().backgroundColor = .clear
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color("backgroundTop"), Color("backgroundBottom")]), startPoint: .topLeading, endPoint: .bottomTrailing).edgesIgnoringSafeArea(.all)
                Form {
                    Section {
                        Picker("Keel", selection: $globals.language) {
                            ForEach(Language.allLanguages, id: \.self) {
                                Text($0.rawValue)
                            }
                        }
                        Picker("Ühik", selection: $globals.unit) {
                            ForEach(unitsArray, id: \.self) {
                                Text($0)
                            }
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
                        TitleView(title: "SETTINGS_TITLE".localized(Globals().language))
                    }
                }
            }
        }.navigationBarTitle("Favorites")
    }
}

    struct SettingsView_Previews: PreviewProvider {
        static var previews: some View {
            SettingsView()
        }
    }
    

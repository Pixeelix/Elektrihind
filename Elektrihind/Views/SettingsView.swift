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
                    Section {
                        Picker("Ühik", selection: $shared.unit) {
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
                        TitleView(title: "Seaded")
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

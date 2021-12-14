//
//  SettingsView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 14.12.2021.
//

import SwiftUI

struct SettingsView: View {
    @State private var selectedStrength = "Mild"
    let strengths = ["Mild", "Medium", "Mature"]
    
    var body: some View {
        Text("Seaded")
    }
    
    //           NavigationView {
    //               Form {
    //                   Section {
    //                       Picker("Strength", selection: $selectedStrength) {
    //                           ForEach(strengths, id: \.self) {
    //                               Text($0)
    //                           }
    //                       }
    //                   }
    //               }
    //           }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

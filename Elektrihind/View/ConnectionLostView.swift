//
//  ConnectionLostView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 03.04.2023.
//

import SwiftUI

struct ConnectionLostView: View {
    @EnvironmentObject var shared: Globals
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            
            VStack {
                Image(systemName: "wifi.slash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .foregroundColor(.white)
                
                Text(shared.localizedString("TEXT_CONNECTION_LOST"))
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding()
                
                Button {
                    self.settingsOpener()
                } label: {
                    Text(shared.localizedString("TITLE_OPEN_SETTINGS"))
                        .padding()
                        .font(.headline)
                        .foregroundColor(Color.blueGrayText)
                }
                .frame(width: 160)
                .background(Color.white)
                .clipShape(Capsule())
                .padding()
            }
        }
    }
    
    private func settingsOpener(){
        if let url = URL(string: "App-prefs:") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}

struct ConnectionLostView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionLostView().environmentObject(Globals())
    }
}

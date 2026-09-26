//
//  ConnectionLostView.swift
//  NordPrice
//
//  Created by Martin Pihooja on 03.04.2023.
//

import SwiftUI

struct ConnectionLostView: View {
    @EnvironmentObject var settings: AppSettings
    @ScaledMetric(relativeTo: .title3) private var messageFontSize: CGFloat = 20
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            
            VStack {
                Image(systemName: "wifi.slash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .foregroundColor(Color.textOnBackground)
                    .accessibilityHidden(true)
                
                Text(settings.localizedString("TEXT_CONNECTION_LOST"))
                    .font(.system(size: messageFontSize))
                    .foregroundColor(Color.textOnBackground)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button {
                    self.settingsOpener()
                } label: {
                    Text(settings.localizedString("TITLE_OPEN_SETTINGS"))
                        .padding()
                        .font(.headline)
                        .foregroundColor(Color("pillButtonText"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minWidth: 160)
                .background(Color("pillButtonBackground"))
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
        ConnectionLostView().environmentObject(AppSettings())
    }
}

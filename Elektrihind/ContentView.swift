//
//  ContentView.swift
//  NordPrice
//
//  Created by Martin Pihooja on 17.11.2021.
//

import SwiftUI
import WidgetKit

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var navigation: AppNavigation
    @EnvironmentObject var networkManager: NetworkManager
    
    var body: some View {
        if networkManager.isConnected || AppRuntimeConfiguration.usesSamplePriceData {
            TabBarView(selection: $navigation.selectedTab)
                .onAppear() {
                    settings.getSavedSettings()
                    if AppRuntimeConfiguration.usesSamplePriceData {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    Task { @MainActor in
                        await NotificationService.shared.registerForRemoteNotificationsIfNeeded()
                        settings.syncRemoteNotificationPreferences()
                    }
                }
        } else {
            ConnectionLostView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(ColorScheme.allCases, id: \.self) {
            ContentView().preferredColorScheme($0)
        }
    }
}

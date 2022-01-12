//
//  ElektrihindApp.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import SwiftUI

@main
struct ElektrihindApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(Globals())
        }
    }
}

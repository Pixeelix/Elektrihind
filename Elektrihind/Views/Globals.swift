//
//  Globals.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 14.12.2021.
//

import Foundation

class Globals: ObservableObject {
  @Published var unit = "€/kWh"
  @Published var temperature = 0.0
}

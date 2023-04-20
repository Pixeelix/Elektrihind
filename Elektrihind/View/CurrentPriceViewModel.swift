//
//  CurrentPriceViewModel.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 04.04.2023.
//

import Foundation
import SwiftUI

class CurrentPriceViewModel: ObservableObject {
    @Published var currenPriceTimeStamp: String = "--:--"
    @Published var currenPrice: String = "---"
    @Published var unit = "---"
    private var currentPriceData: PriceData?
    private var dataLastLoaded: Date? = nil
    private var shared = Globals()
    
    func setup(_ shared: Globals) {
      self.shared = shared
    }
    
    func loadCurrentPrice() {
        if shouldLoadData() {
            Network().loadCurrentPrice(region: shared.region) { data in
                self.currentPriceData = data
                self.updateCurrentPrice()
                self.dataLastLoaded = Date()
            }
        } else {
            updateCurrentPrice()
        }
    }
    
    private func updateCurrentPrice() {
        guard let data = currentPriceData else { return }
        self.getCurrentTimeStampFrom(data.timestamp)
        self.getCurrentPriceFrom(data.price)
        self.unit = self.shared.localizedString(self.shared.unit)
    }
    
    private func shouldLoadData() -> Bool {
        if shared.todayDataUpdateMandatory {
            return true
        }
        if let dataLastLoaded = dataLastLoaded,
           Calendar.current.isDate(dataLastLoaded, equalTo: Date(), toGranularity: .hour) {
            return false
        } else {
            return true
        }
    }
    
    private func getCurrentTimeStampFrom(_ timeStamp: Double) {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "EET")
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "HH:mm"
        let date = Date(timeIntervalSince1970: timeStamp)
        self.currenPriceTimeStamp = dateFormatter.string(from: date)
    }
    
    private func getCurrentPriceFrom(_ price: Double) {
        let priceWithTax = shared.includeTax ? price * shared.taxRate : price
        let formattedPrice = shared.numberFormatter.string(from: NSNumber(value: priceWithTax / shared.divider))
        self.currenPrice = formattedPrice ?? "---"
    }
}

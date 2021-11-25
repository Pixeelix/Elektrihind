//
//  NordPoolPrice.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import Foundation

struct NordPoolCountriesData: Decodable {
    let data: Countries
    let success: Bool
}

struct NordPoolCurrentData: Decodable {
    let data: [PriceData]
}

struct Countries: Decodable {
    let ee, fi, lt, lv: [PriceData]
}

struct PriceData: Decodable {
    let timestamp: Int
    let price: Double
}

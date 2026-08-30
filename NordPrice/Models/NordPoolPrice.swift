//
//  NordPoolPrice.swift
//  NordPrice
//
//  Created by Martin Pihooja on 17.11.2021.
//

import Foundation

struct NordPoolCountriesData: Decodable {
    let data: Countries
    let success: Bool
}

struct Countries: Decodable {
    let ee, fi, lt, lv: [PriceData]
}

struct PriceData: Decodable {
    let timestamp: Double
    let price: Double
}


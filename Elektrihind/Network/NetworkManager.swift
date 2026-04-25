//
//  NetworkManager.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import Foundation
import SwiftUI
import Network

class NetworkManager: ObservableObject {
    let monitor = NWPathMonitor()
    let queue = DispatchQueue(label: "NetworkManager")
    @Published var isConnected = true

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

class NetworkService {
    private let repository = PriceRepository()

    func loadFullDayData(_ day: Day, region: Region) async throws -> [PriceData] {
        return try await repository.loadFullDayData(day, region: region)
    }
}

//
//  Network.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import Foundation
import Network

enum Day {
    case today
    case tomorrow
}

class NetworkManager: ObservableObject {
    let monitor = NWPathMonitor()
    let queue = DispatchQueue(label: "NetworkManager")
    @Published var isConnected = true
    
    init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.sync {
                self.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}

class Network: ObservableObject {
    private let unit = Globals().unit
    private let divider: Double = Globals().divider
    private let taxStatus = Globals().includeTax
    
    func loadCurrentPrice(completion:@escaping (PriceData) -> ()) {

        guard let url = URL(string: "https://dashboard.elering.ee/api/nps/price/EE/current") else { fatalError("Missing URL") }
        let urlRequest = URLRequest(url: url)
        
        let dataTask = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print("Request error: ", error)
                return
            }
            
            guard let response = response as? HTTPURLResponse else { return }
            
            if response.statusCode == 200 {
                guard let data = data else { return }
                DispatchQueue.main.async {
                    do {
                        let decodedNordPoolData = try
                        JSONDecoder().decode(NordPoolCurrentData.self, from: data)
                        if let currentEstPrice = decodedNordPoolData.data.first {
                            completion(currentEstPrice)
                        }
                    } catch let error {
                        print("Error decoding: ", error)
                    }
                }
            }
        }
        dataTask.resume()
    }
    
    func loadFullDayData(_ day: Day, completion:@escaping ([PriceData]) -> ()) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let yesterDay = dateFormatter.string(from: Date().dayBefore)
        let today = dateFormatter.string(from: Date())
        let tomorrow = dateFormatter.string(from: Date().dayAfter)
        let timeZoneDifference = TimeZone.current.secondsFromGMT()/3600 // Hours
        
        var startDate: String = yesterDay
        var endDate: String = today
        let startTime = 24 - timeZoneDifference
        let endTime = 24 - (timeZoneDifference + 1)
        
        if day == .tomorrow {
            startDate = today
            endDate = tomorrow
        }

        guard let url = URL(string: "https://dashboard.elering.ee/api/nps/price?start=\(startDate)T\(startTime):00:00.000Z&end=\(endDate)T\(endTime):59:59.999Z") else { fatalError("Missing URL") }
        print(url)
        let urlRequest = URLRequest(url: url)
        let dataTask = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print("Request error: ", error)
                return
            }
            
            guard let response = response as? HTTPURLResponse else { return }
            
            if response.statusCode == 200 {
                guard let data = data else { return }
                DispatchQueue.main.async {
                    do {
                        let decodedNordPoolData = try JSONDecoder().decode(NordPoolCountriesData.self, from: data)
                        var fullDayData = [PriceData]()
                        for data in decodedNordPoolData.data.ee {
                            fullDayData.append(data)
                        }
                        completion(fullDayData)
                    } catch let error {
                        print("Error decoding: ", error)
                    }
                }
            }
        }
        dataTask.resume()
    }
}

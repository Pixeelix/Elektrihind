//
//  Network.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import Foundation

enum Day {
    case today
    case tomorrow
}

class Network: ObservableObject {
    
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
                            print(currentEstPrice)
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
    
    func loadEstDayData(_ day: Day, completion:@escaping ([(String, Double)]) -> ()) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let yesterDay = dateFormatter.string(from: Date().dayBefore)
        let today = dateFormatter.string(from: Date())
        let tomorrow = dateFormatter.string(from: Date().dayAfter)
        
        var startDate: String = yesterDay
        var endDate: String = today
        
        if day == .tomorrow {
            startDate = today
            endDate = tomorrow
        }
        
        let testFormatter = DateFormatter()
        testFormatter.timeZone = TimeZone(abbreviation: "EET") //Set timezone that you want
        testFormatter.locale = NSLocale.current
        testFormatter.dateFormat = "HH:mm" //Specify your format that you want
        
        guard let url = URL(string: "https://dashboard.elering.ee/api/nps/price?start=\(startDate)T22:00:00.000Z&end=\(endDate)T21:59:59.999Z") else { fatalError("Missing URL") }
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
                        let decodedNordPoolData = try
                        JSONDecoder().decode(NordPoolCountriesData.self, from: data)
                        var estonianDayDataArray: [(String, Double)] = []
                        for data in decodedNordPoolData.data.ee {
                            let timeStampDate = Date(timeIntervalSince1970: data.timestamp)
                            let strTime = testFormatter.string(from: timeStampDate)
                            let dataPoint = (strTime, data.price)
                            estonianDayDataArray.append(dataPoint)
                        }
                        completion(estonianDayDataArray)
                    } catch let error {
                        print("Error decoding: ", error)
                    }
                }
            }
        }
        dataTask.resume()
    }
}

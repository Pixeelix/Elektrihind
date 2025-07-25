//
//  Extensions.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 17.11.2021.
//

import Foundation
import UIKit
import SwiftUI

extension Date {
    static var yesterday: Date { return Date().dayBefore }
    static var tomorrow:  Date { return Date().dayAfter }
    var dayBefore: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: noon)!
    }
    var dayAfter: Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: noon)!
    }
    var noon: Date {
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
    }
    var month: Int {
        return Calendar.current.component(.month,  from: self)
    }
    var isLastDayOfMonth: Bool {
        return dayAfter.month != month
    }
}

extension String {
    
    func localized(_ language: Language) -> String {
        let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj")
        let bundle: Bundle
        if let path = path {
            bundle = Bundle(path: path) ?? .main
        } else {
            bundle = .main
        }
        return localized(bundle: bundle)
    }

    private func localized(bundle: Bundle) -> String {
        return NSLocalizedString(self, tableName: nil, bundle: bundle, value: "", comment: "")
    }
}

extension UIScreen {
    static let screenWidth = UIScreen.main.bounds.size.width
    static let screenHeight = UIScreen.main.bounds.size.height
    static let is1stGenIphone = screenHeight <= 568
    static let isIphone8 = screenHeight <= 667
    static let isTallScreen = screenHeight > 667
}

extension Bundle {
    func decode<T: Decodable>(file: String) -> T {
        guard let url = self.url(forResource: file, withExtension: nil) else {
            fatalError("Could not find \(file) in the project")
        }
        
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Could not load \(file) in the project")
        }
        
        let decoder = JSONDecoder()
        guard let loadedData = try? decoder.decode(T.self, from: data) else {
            fatalError("Could not decode \(file) in the project")
        }
        
        return loadedData
    }
}

extension Color {
    static let blueGrayText = Color("blueGrayText")
    static let bluewWhiteText = Color("blueWhiteText")
    static let contentBoxBackground = Color("contentBoxBackground")
    static let tabBarBackground = Color("tabBarBackground")
    static let backgroundColor = LinearGradient(gradient: Gradient(colors: [Color("backgroundTop"), Color("backgroundBottom")]), startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Data {
    func printAsJSON() {
            if let theJSONData = try? JSONSerialization.jsonObject(with: self, options: []) as? NSDictionary {
                var swiftDict: [String: Any] = [:]
                for key in theJSONData.allKeys {
                    let stringKey = key as? String
                    if let key = stringKey, let keyValue = theJSONData.value(forKey: key) {
                        swiftDict[key] = keyValue
                    }
                }
                swiftDict.printAsJSON()
            }
        }
}

public extension Dictionary {
    
    func printAsJSON() {
        if let theJSONData = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted),
            let theJSONText = String(data: theJSONData, encoding: String.Encoding.ascii) {
            print("\(theJSONText)")
        }
    }
}


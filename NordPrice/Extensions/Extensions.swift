//
//  Extensions.swift
//  NordPrice
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
    /// Accent: system blue in light mode (original look), website brand blue in dark.
    static let brand = Color("brandAccent")
    /// Text placed directly on the page background: white in light, ink in dark.
    static let textOnBackground = Color("textOnBackground")
    /// Small labels inside cards: blue in light, muted ink in dark.
    static let cardLabelText = Color("cardLabelText")
    /// Thin ring around cards, only visible in dark mode (website's `ring-ink/8`).
    static let cardStroke = Color("cardStroke")
    static let backgroundColor = LinearGradient(gradient: Gradient(colors: [Color("backgroundTop"), Color("backgroundBottom")]), startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension View {
    /// Card with rounded corners; in dark mode also a subtle ring, like the website cards.
    func cardStyle(cornerRadius: CGFloat) -> some View {
        self
            .background(Color.contentBoxBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.cardStroke, lineWidth: 1)
            )
    }

    /// Current-price card: same card as the others, with the primary text color.
    func heroCardStyle(cornerRadius: CGFloat) -> some View {
        self
            .foregroundColor(Color.bluewWhiteText)
            .cardStyle(cornerRadius: cornerRadius)
    }

    /// The price screens are laid out to fill exactly one screen. At accessibility
    /// text sizes that no longer fits, so the content scrolls instead.
    func scrollsAtAccessibilitySizes() -> some View {
        modifier(ScrollsAtAccessibilitySizes())
    }
}

private struct CardWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat? = UIScreen.main.bounds.width * 0.9
}

extension EnvironmentValues {
    /// Width of the price cards and the chart. The phone layout uses 90% of the
    /// screen; `nil` lets the card fill its container (the iPad dashboard).
    var cardWidth: CGFloat? {
        get { self[CardWidthKey.self] }
        set { self[CardWidthKey.self] = newValue }
    }
}

extension View {
    func cardWidth() -> some View {
        modifier(CardWidthModifier())
    }
}

private struct CardWidthModifier: ViewModifier {
    @Environment(\.cardWidth) private var width

    func body(content: Content) -> some View {
        if let width {
            content.frame(width: width)
        } else {
            content.frame(maxWidth: .infinity)
        }
    }
}

private struct ScrollsAtAccessibilitySizes: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView {
                content.frame(maxWidth: .infinity)
            }
        } else {
            content
        }
    }
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


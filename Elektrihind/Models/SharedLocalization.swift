//
//  SharedLocalization.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 08.10.2025.
//

import Foundation

enum Language: String {
    case estonian = "et"
    case english = "en"
    case finnish = "fi"
    case russian = "ru"
    
    static let allLanguages = [estonian, english, finnish, russian]
    var name: String {
      get {
        switch self {
        case .estonian:
            return "ESTONIAN"
          case .english:
            return "ENGLISH"
        case.finnish:
            return "FINNISH"
        case.russian:
            return "RUSSIAN"
        }
      }
    }
}

extension String {
    func localized(_ language: Language, in bundle: Bundle) -> String {
        if let path = bundle.path(forResource: language.rawValue, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            return NSLocalizedString(self, bundle: langBundle, comment: "")
        }
        return NSLocalizedString(self, bundle: bundle, comment: "")
    }
}
